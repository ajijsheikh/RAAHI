"""IRCTC travel-claim verification client.

There is no official free IRCTC API. This client is env-driven:
  IRCTC_ENABLED=true        -> attempt live calls (RapidAPI-style provider)
  IRCTC_API_KEY / IRCTC_API_HOST -> provider credentials

Without credentials the client returns SIMULATED data explicitly marked
"source": "simulated" so callers/UI never mistake it for a live result.
"""

import os
import hashlib
from typing import Optional, Dict, Any

import httpx

SIMULATED_NOTE = (
    "Simulated PNR data - no IRCTC_API_KEY configured. "
    "Set IRCTC_ENABLED/IRCTC_API_KEY/IRCTC_API_HOST for live lookups."
)


def _deterministic_seed(pnr: str) -> int:
    return int(hashlib.sha256(pnr.encode()).hexdigest()[:8], 16)


async def check_pnr(pnr: str) -> Dict[str, Any]:
    """Return PNR status dict with an explicit 'source' field.

    Live path: GET https://{IRCTC_API_HOST}/api/v1/pnrStatus?pnrNumber={pnr}
    Simulated path: deterministic demo data derived from the PNR itself.
    """
    if os.getenv("IRCTC_ENABLED", "").lower() == "true":
        api_key = os.getenv("IRCTC_API_KEY")
        api_host = os.getenv("IRCTC_API_HOST")
        if api_key and api_host:
            try:
                async with httpx.AsyncClient(timeout=10) as client:
                    resp = await client.get(
                        f"https://{api_host}/api/v1/pnrStatus",
                        params={"pnrNumber": pnr},
                        headers={
                            "X-RapidAPI-Key": api_key,
                            "X-RapidAPI-Host": api_host,
                        },
                    )
                    resp.raise_for_status()
                    data = resp.json()
                    data["source"] = "live"
                    return data
            except httpx.HTTPError as e:
                # Fall through to simulated rather than failing the request,
                # but surface the error explicitly.
                return {
                    "pnr": pnr,
                    "source": "simulated",
                    "note": f"Live lookup failed ({type(e).__name__}); served simulated data.",
                    **_simulated_pnr(pnr),
                }

    return {"pnr": pnr, "source": "simulated", "note": SIMULATED_NOTE, **_simulated_pnr(pnr)}


def _simulated_pnr(pnr: str) -> Dict[str, Any]:
    seed = _deterministic_seed(pnr)
    stations = ["Howrah Jn", "Sealdah", "Bidhannagar", "Dum Dum", "Kharagpur"]
    origin = stations[seed % len(stations)]
    dest = stations[(seed // 7) % len(stations)]
    if dest == origin:
        dest = stations[(seed % len(stations) + 1) % len(stations)]
    status_options = ["CONFIRMED", "RAC", "WAITING LIST"]
    return {
        "train_number": f"{12000 + seed % 9999}",
        "train_name": "Raahi Demo Express",
        "origin": origin,
        "destination": dest,
        "status": status_options[seed % len(status_options)],
        "boarding_station": origin,
        "arrival_station": dest,
        "scheduled_departure": f"{5 + seed % 16:02d}:{(seed * 7) % 60:02d}",
        "delay_min": seed % 25,
    }


async def verify_travel_claim(pnr: str, claimed_destination: Optional[str] = None) -> Dict[str, Any]:
    """Cross-check a claimed destination against PNR arrival station."""
    pnr_data = await check_pnr(pnr)
    result: Dict[str, Any] = {**pnr_data, "claim_verified": None}

    if claimed_destination and pnr_data.get("arrival_station"):
        match = claimed_destination.strip().lower() in str(
            pnr_data["arrival_station"]
        ).lower()
        result["claim_verified"] = match
        result["claimed_destination"] = claimed_destination

    return result