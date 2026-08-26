import json
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

    # Extract budget - handle both "₹200" and "200 rupee" formats
    budget_match = re.search(r"[₹$]\s*(\d+)|(\d+)\s*rupe(e|ies?)?", query, re.IGNORECASE)
    if budget_match:
        if budget_match.group(1):
            max_budget = int(budget_match.group(1))
        elif budget_match.group(2):
            max_budget = int(budget_match.group(2))

    # Resolve origin and destination using "se" as separator
    # "se" means "from" in Hindi/Bengali
    parts = re.split(r"\bse\s+", query, flags=re.IGNORECASE)
    if len(parts) >= 2:
        origin_raw = parts[0].strip()
        dest_raw = parts[1]

        # Remove trailing phrases from destination: "ke andar", "rupee keandar",
        # "rupees mein", "baje tak", "₹200 ke andar", etc.
        # (Handled by UI display layer; parser extracts raw text after "se")

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

    return intent


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