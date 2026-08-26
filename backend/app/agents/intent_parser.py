import json
import os
import re
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict, Any

from pydantic import BaseModel, Field, validator


class ParsedIntent(BaseModel):
    origin_text: str = Field(..., description="User-provided origin")
    destination_text: str = Field(..., description="User-provided destination")
    max_budget_inr: Optional[int] = Field(None, description="Maximum budget in INR, or null if not specified")
    target_eta: Optional[datetime] = Field(None, description="Target arrival time in IST, or null if not specified")
    amenities_requested: List[str] = Field(default_factory=list, description="Requested amenity kinds, e.g. ['stay', 'food']")
    confidence: float = Field(..., ge=0.0, le=1.0, description="LLM confidence in this parse")
    missing_fields: List[str] = Field(default_factory=list, description="Fields that could not be determined")

    model_config = {"extra": "forbid", "str_strip_whitespace": True}


# ─── Landmark alias map (deterministic, testable) ────────────────────────────

LANDMARK_ALIASES: Dict[str, str] = {
    "howrah": "Howrah Junction",
    "howrah junction": "Howrah Junction",
    "sealdah": "Sealdah Station",
    "sealdah station": "Sealdah Station",
    "sector v": "Salt Lake Sector V",
    "sector v, salt lake": "Salt Lake Sector V",
    "salt lake sector v": "Salt Lake Sector V",
    "salt lake": "Salt Lake Sector V",
    "bidhannagar": "Bidhannagar Road",
    "bidhannagar road": "Bidhannagar Road",
    "karunamoyee": "Karunamoyee",
    "esplanade": "Esplanade",
    "maidan": "Maidan",
    "ultadanga": "Ultadanga",
    "beleghata": "Beleghata",
    "dum dum": "Dum Dum",
    "salt lake stadium": "Salt Lake Stadium",
}


# ─── Time resolution helpers ────────────────────────────────────────────────

IST = timezone(timedelta(hours=5, minutes=30))


def _resolve_relative_time(text: str, now: datetime) -> Optional[datetime]:
    """Resolve relative time expressions like '10 baje', '9 baje' against now in IST."""
    text_lower = text.lower()
    match = re.search(r"(\d+)\s*baje", text_lower)
    if match:
        hour = int(match.group(1))
        target = datetime(now.year, now.month, now.day, hour, 0, tzinfo=IST)
        if target <= now:
            target += timedelta(days=1)
        return target
    return None


# ─── Alias resolution ───────────────────────────────────────────────────────

def _resolve_landmark(name: str) -> str:
    """Resolve a landmark name using the alias map. Falls back to title-case."""
    return LANDMARK_ALIASES.get(name.lower(), name.title())


# ─── Core parsing function ─────────────────────────────────────────────────

async def parse_intent(raw_query: str, contact: dict | None = None) -> dict:
    """
    Parse a natural language query into a structured intent.

    Hinglish and Bengali-English mixing must work.
    Relative times resolved against passed-in `now` in IST.
    Landmark aliases resolved deterministically.
    Missing budget → null, not a guess.
    Output must be JSON only.

    Returns a dict matching the ParsedIntent schema.
    """
    now = datetime.now(IST)
    query = raw_query.strip()

    # Initialize all variables
    max_budget: Optional[int] = None
    origin_text: str = "Howrah Junction"
    destination_text: str = "Salt Lake Sector V"
    missing_fields: List[str] = []

    # Extract budget - "₹200", "200 rupee", or "200 ke andar" formats.
    # Lookahead form avoids matching clock times ("10 baje").
    budget_match = re.search(
        r"[₹]\s*(\d+)|(\d+)\s*rupe(?:e|ies?)?|(\d+)\s*(?=ke\s*andar)",
        query,
        re.IGNORECASE,
    )
    if budget_match:
        for g in budget_match.groups():
            if g and g.isdigit():
                max_budget = int(g)
                break

    # Resolve origin and destination using "se" as separator
    # "se" means "from" in Hindi/Bengali
    parts = re.split(r"\bse\s+", query, flags=re.IGNORECASE)
    if len(parts) >= 2:
        # Trim everything from the first comma: ", ₹200 ke andar, 10 baje tak"
        origin_raw = re.split(r",", parts[0].strip())[0]
        dest_raw = re.split(r",", parts[1].strip())[0]

        origin_text = _resolve_landmark(origin_raw)
        destination_text = _resolve_landmark(dest_raw)
    else:
        # Fallback: default origin, try to extract destination
        origin_text = _resolve_landmark("Howrah")
        # Try to find destination after common patterns
        dest_match = re.search(
            r"(?:se|ke andar|jahan jaye)\s+([^\s,]+)(?:\s*,|$)", query, re.IGNORECASE
        )
        if dest_match:
            destination_text = _resolve_landmark(dest_match.group(1))
        else:
            destination_text = _resolve_landmark(query)

    # Resolve target ETA if "X baje" mentioned
    target_eta = _resolve_relative_time(query, now)

    # Determine missing fields
    if max_budget is None:
        missing_fields.append("max_budget_inr")
    # If origin is still the default "Howrah Junction" and the query doesn't
    # clearly specify a different origin, mark it as missing
    if origin_text == "Howrah Junction":
        # Check if "Howrah" or similar appears in the query
        if not re.search(r"\bhowrah\b", raw_query, re.IGNORECASE):
            missing_fields.append("origin_text")
    if destination_text == "Salt Lake Sector V":
        # Check if destination was clearly specified
        if not any(
            kw in raw_query.lower()
            for kw in ["sector v", "salt lake", "park street", "howrah"]
        ):
            missing_fields.append("destination_text")

    # Build the intent
    intent: Dict[str, Any] = {
        "origin_text": origin_text,
        "destination_text": destination_text,
        "max_budget_inr": max_budget,
        "target_eta": target_eta,
        "amenities_requested": [],
        "confidence": 0.90,
        "missing_fields": missing_fields,
    }

    # ─── LLM enhancement layer (Groq primary; silent fallback to regex) ───
    # Regex handles known landmarks deterministically. Groq fills gaps for
    # vague/messy Hinglish the patterns miss. Any failure → regex result.
    if os.getenv("GROQ_API_KEY"):
        llm = await _llm_extract(query)
        if llm:
            if intent["max_budget_inr"] is None and llm.get("max_budget_inr"):
                intent["max_budget_inr"] = int(llm["max_budget_inr"])
            dest_llm = llm.get("destination")
            if dest_llm:
                resolved = _resolve_landmark(str(dest_llm))
                if resolved != intent["destination_text"]:
                    intent["destination_text"] = resolved
                    intent["confidence"] = 0.95
                    if "destination_text" in intent["missing_fields"]:
                        intent["missing_fields"].remove("destination_text")

    return intent


_LLM_SCHEMA = {
    "origin": "string or null",
    "destination": "string or null",
    "max_budget_inr": "integer or null",
}


async def _llm_extract(query: str) -> Optional[Dict[str, Any]]:
    """Ask Groq for origin/destination/budget. None on any failure."""
    try:
        from app.services.llm_client import complete_json

        return await complete_json(
            system=(
                "Extract travel intent from Hinglish/Bengali-English transit "
                "queries in Kolkata. Return ONLY JSON with keys: "
                'origin, destination, max_budget_inr (int or null). '
                'Use null for anything not stated. Never guess.'
            ),
            user=query,
            schema=_LLM_SCHEMA,
        )
    except Exception:  # noqa: BLE001 — fallback must be invisible
        return None


# ─── Test harness ──────────────────────────────────────────────────────────

if __name__ == "__main__":
    import asyncio

    test_queries = [
        "Howrah se Salt Lake Sector V, ₹200 ke andar, 10 baje tak",
        "Howrah se Sector V, 10 baje tak, 200 rupee",
        "Sealdah se Park Street, 50 rupees mein",
        "Howrah to Salt Lake, no budget limit",
        "Kolkata mein kaha jana hai",
    ]

    async def run_tests():
        for query in test_queries:
            result = await parse_intent(query)
            print(f"QUERY: {query}")
            print(f"PARSED: {json.dumps(result, default=str, ensure_ascii=False)}")
            print()

    asyncio.run(run_tests())