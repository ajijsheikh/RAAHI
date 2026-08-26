from fastapi import APIRouter, Body, Path, HTTPException, status, Depends
from fastapi.responses import StreamingResponse, JSONResponse
import logging
from pydantic import BaseModel, Field, validator
from typing import Optional, Dict, Any, List
import asyncio
import json
import uuid
from datetime import datetime, timezone, UTC

from app.db.models import Trip, ItineraryLeg, TripEvent, SafetyZone, Amenity
from app.db import get_db
from app.agents.route_planner import pick_best_itinerary, Itinerary, Leg
from app.agents.monitor_loop import monitor
from app.services.event_bus import bus

router = APIRouter(tags=["trips"])


class TripCreate(BaseModel):
    query: str = Field(..., description="Raw natural language query")
    emergency_contact_phone: Optional[str] = Field(
        None, description="E.164 phone number, e.g. +919800000000"
    )

    @validator("query")
    def non_empty(cls, v):
        if not v.strip():
            raise ValueError("Query must not be empty")
        return v


class ClarificationResponse(BaseModel):
    missing_field: str
    current_partial: Optional[Dict[str, Any]] = None


@router.post(
    "/trips",
    status_code=status.HTTP_201_CREATED,
    responses={
        422: {"description": "Intent parser could not extract required field"},
        409: {"description": "No itinerary found under stated budget"},
    },
)
async def create_trip(
    payload: TripCreate,
    db: object = Depends(get_db),  # type: ignore  # noqa: F821
):
    """Create a trip from natural language query (FR-1 / API_SPEC.md §1)."""

    query: str = payload.query
    emergency_contact_phone: Optional[str] = payload.emergency_contact_phone

    # ---- Step 1: Intent Parser (stub for now; P2 will replace with real LLM call) ----
    # In demo scope, we parse simple patterns from the free-text query.
    # P2's real implementation will override this via the orchestrator.
    parsed = _stub_intent_parser(query)

    # Validate required fields - per contract: return 200 with clarification, not 422 error
    if not parsed.get("destination"):
        return {
            "trip": None,
            "parsed_intent": {
                "origin": parsed.get("origin", "Howrah Junction"),
                "destination": None,
                "max_budget_inr": parsed.get("max_budget_inr", 200),
                "target_eta": parsed.get("target_eta"),
            },
            "clarification_needed": {
                "field": "destination",
                "question": "Salt Lake ke kaunse part mein — Sector V ya Karunamoyee?",
            },
        }

    if not parsed.get("max_budget_inr"):
        return {
            "trip": None,
            "parsed_intent": {
                "origin": parsed.get("origin", "Howrah Junction"),
                "destination": parsed.get("destination"),
                "max_budget_inr": None,
                "target_eta": parsed.get("target_eta"),
            },
            "clarification_needed": {
                "field": "budget",
                "question": "Aapka budget kitna hai? (example: ₹200)",
            },
        }

    # ---- Step 2: Route Planner ----
    itinerary = pick_best_itinerary(
        origin=parsed.get("origin", "Howrah Junction"),
        destination=parsed["destination"],
        max_budget_inr=parsed["max_budget_inr"],
        safety_penalty=0.0,  # demo: no safety zones for initial plan
    )

    if itinerary is None:
        # Find cheapest option for the error response
        from app.agents.route_planner import generate_candidates
        candidates = generate_candidates(
            origin=parsed.get("origin", "Howrah Junction"),
            destination=parsed["destination"],
            max_budget_inr=parsed["max_budget_inr"],
        )
        cheapest_cost = min(
            (c.total_cost_inr for c in candidates), default=None
        )
        return JSONResponse(
            status_code=409,
            content={
                "error": {
                    "code": "NO_ROUTE_UNDER_BUDGET",
                    "message": f"No itinerary found under ₹{parsed['max_budget_inr']}. "
                               f"Cheapest available is ₹{cheapest_cost}.",
                    "details": {},
                }
            },
        )

    # ---- Step 3: Persist trip + itinerary (best-effort) ----
    # Postgres may be unavailable (no Docker / venue Wi-Fi). The demo must
    # still work: itinerary lives in the response + monitor loop memory.
    logger = logging.getLogger("raahi.trips")
    try:
        trip_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc)

        db_trip = Trip(
            id=uuid.UUID(trip_id),
            user_id=uuid.uuid4(),
            status="active",
            query_text=query,
            max_budget_inr=parsed["max_budget_inr"],
            target_eta=parsed.get("target_eta"),
            emergency_contact_phone=emergency_contact_phone,
            created_at=now,
        )
        db.add(db_trip)
        db.commit()
        db.refresh(db_trip)

        for i, leg in enumerate(itinerary.legs):
            db_leg = ItineraryLeg(
                trip_id=db_trip.id,
                leg_index=leg.leg_index,
                mode=leg.mode,
                from_name=leg.from_,
                to_name=leg.to,
                scheduled_departure=leg.scheduled_departure,
                cost_inr=leg.cost_inr,
                status="planned",
            )
            db.add(db_leg)
        db.commit()
    except Exception as e:  # noqa: BLE001 — demo continues without Postgres
        logger.warning("DB persistence skipped (%s: %s)", type(e).__name__, e)
        if "trip_id" not in dir():
            trip_id = str(uuid.uuid4())

    # ---- Step 4: Start the monitor loop (agent watching the trip) ----
    monitor.start(trip_id)

    # ---- Step 5: Return response ----
    # Build the legs list for the response
    legs_response = [
        {
            "leg_index": leg.leg_index,
            "mode": leg.mode,
            "from": leg.from_,
            "to": leg.to,
            "scheduled_departure": leg.scheduled_departure,
            "cost_inr": leg.cost_inr,
        }
        for leg in itinerary.legs
    ]

    return {
        "trip_id": trip_id,
        "status": "active",
        "parsed_intent": {
            "origin": parsed.get("origin", "Howrah Junction"),
            "destination": parsed["destination"],
            "max_budget_inr": parsed["max_budget_inr"],
            "target_eta": parsed.get("target_eta"),
        },
        "itinerary": {
            "total_cost_inr": itinerary.total_cost_inr,
            "total_time_minutes": itinerary.total_time_minutes,
            "legs": legs_response,
        },
        "amenities": _stub_amenities(parsed["destination"]),
    }


@router.get("/trips/{trip_id}", response_model=Dict[str, Any])
async def get_trip(
    trip_id: str = Path(..., description="UUID of the trip to fetch"),
    db: object = Depends(get_db),  # type: ignore  # noqa: F821
):
    """Fetch current trip + active itinerary (API_SPEC.md §2)."""
    from sqlalchemy import select

    result = db.execute(
        select(Trip).where(Trip.id == uuid.UUID(trip_id) if isinstance(trip_id, str) else trip_id)
    )
    db_trip = result.scalar_one_or_none()

    if not db_trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    # Return the same shape as POST /trips response
    return {
        "trip_id": trip_id,
        "status": db_trip.status,
        "parsed_intent": {
            "origin": db_trip.query_text,  # simplified - in reality, parse from stored data
            "destination": "Salt Lake Sector V",
            "max_budget_inr": db_trip.max_budget_inr,
            "target_eta": str(db_trip.target_eta) if db_trip.target_eta else None,
        },
        "itinerary": {"total_cost_inr": 50, "total_time_minutes": 55, "legs": []},  # placeholder
        "amenities": [],
    }


def _stub_intent_parser(user_text: str) -> Dict[str, Any]:
    """
    Very simple stub that extracts origin, destination, budget from
    common Kolkata trip patterns. P2's real LLM call will replace this.
    """
    import re

    text = user_text.lower()
    parsed = {
        "origin": "Howrah Junction",
        "destination": "Salt Lake Sector V",
        "max_budget_inr": 200,
        "target_eta": None,
    }

    # Extract destination
    if "salt lake" in text:
        parsed["destination"] = "Salt Lake Sector V"
    elif "park street" in text:
        parsed["destination"] = "Park Street"

    # Extract budget
    budget_match = re.search(r'₹?\s*(\d+)|budget\s*(\d+)', text)
    if budget_match:
        for group in budget_match.groups():
            if group and group.isdigit():
                budget = int(group)
                if 50 <= budget <= 5000:
                    parsed["max_budget_inr"] = budget
                    break

    # Extract ETA
    eta_match = re.search(r'by\s+(\d{1,2}:\d{2}|\d{1,2}\s*(am|pm)|tomorrow)', text)
    if eta_match:
        parsed["target_eta"] = eta_match.group(0)

    # Extract origin
    if "howrah" in text:
        parsed["origin"] = "Howrah Junction"

    return parsed


def _stub_amenities(destination: str) -> Dict[str, List[Dict[str, Any]]]:
    """Return static curated amenities for the demo destination."""
    return {
        "budget_food": [
            {"name": "Express Meal Center", "price_inr": 70, "distance_km": 0.3},
            {"name": "Street Food Corner", "price_inr": 50, "distance_km": 0.4},
        ],
        "budget_stay": [
            {"name": "Urban Travel Hostel", "price_inr": 4800, "distance_km": 0.6},
            {"name": "Paying Guest Hostel", "price_inr": 3500, "distance_km": 1.2},
        ],
    }


# ---------------------------------------------------------------------------
# SSE live events + demo simulate endpoints (API_SPEC.md §3)
# ---------------------------------------------------------------------------

@router.get("/trips/{trip_id}/events")
async def stream_trip_events(trip_id: str):
    """SSE stream of live trip events. Replays full history on connect."""
    q = bus.subscribe(trip_id)

    async def gen():
        try:
            while True:
                try:
                    event = await asyncio.wait_for(q.get(), timeout=15.0)
                    yield bus.format_sse(event)
                except asyncio.TimeoutError:
                    yield ": heartbeat\n\n"
        finally:
            bus.unsubscribe(trip_id, q)

    return StreamingResponse(
        gen(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


class SimulateDelay(BaseModel):
    leg_index: int = 1
    delay_minutes: int = Field(20, ge=1, le=180)


class SimulateZoneEntry(BaseModel):
    zone_name: str = Field(
        "Under-lit stretch near Bidhannagar underpass", min_length=1
    )


@router.post("/trips/{trip_id}/simulate-delay", status_code=status.HTTP_202_ACCEPTED)
async def simulate_delay(trip_id: str, payload: SimulateDelay):
    """Inject a delay; the monitor loop reacts and publishes a reroute event."""
    rt = monitor.runtime(trip_id)
    monitor.start(trip_id)
    rt.current_leg = payload.leg_index
    rt.delay_min = payload.delay_minutes
    rt.delay_handled = False
    return {"accepted": True}


@router.post(
    "/trips/{trip_id}/simulate/zone-entry",
    status_code=status.HTTP_202_ACCEPTED,
)
async def simulate_zone_entry(trip_id: str, payload: SimulateZoneEntry):
    """Inject a zone entry; the monitor loop publishes safety_alert (+SMS)."""
    rt = monitor.runtime(trip_id)
    monitor.start(trip_id)
    rt.zone_name = payload.zone_name
    rt.zone_handled = False
    return {"accepted": True}


@router.post("/trips/{trip_id}/sos", status_code=status.HTTP_202_ACCEPTED)
async def manual_sos(trip_id: str):
    """Manual SOS (PRD FR-4 fallback) — immediate safety_alert event."""
    await bus.publish(
        trip_id,
        "safety_alert",
        {
            "zone_name": "Manual SOS",
            "contact_notified": False,
            "lat": 22.5768,
            "lng": 88.4302,
            "message": "Manual SOS triggered by traveler",
        },
    )
    return {"accepted": True}