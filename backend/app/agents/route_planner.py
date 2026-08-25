from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone, UTC


UTC = timezone.utc
# Kolkata is UTC+5:30 for demo purposes
KOLKATA_OFFSET = timedelta(hours=5, minutes=30)
KOLKATA_TZ = timezone(KOLKATA_OFFSET)


@dataclass
class Leg:
    leg_index: int
    mode: str
    from_: str
    to: str
    scheduled_departure: datetime
    cost_inr: int
    travel_time_minutes: int


@dataclass
class Itinerary:
    total_cost_inr: int
    total_time_minutes: int
    legs: List[Leg]


def utility_score(
    itinerary: Itinerary,
    max_budget_inr: int,
    w1: float = 0.5,
    w2: float = 0.3,
    w3: float = 0.2,
    safety_penalty: float = 0.0,
) -> float:
    """
    Score an itinerary using a weighted utility function.

    score = w1 * (1 / travel_time) - w2 * (cost / max_budget) - w3 * (safety_penalty)

    Constraints:
    - If cost > max_budget, return -inf (automatically disqualified).
    - travel_time in minutes must be > 0.
    """
    if itinerary.total_cost_inr > max_budget_inr:
        return -float("inf")

    if itinerary.total_time_minutes <= 0:
        return -float("inf")

    travel_time_factor = 1.0 / itinerary.total_time_minutes
    cost_factor = itinerary.total_cost_inr / max_budget_inr

    return w1 * travel_time_factor - w2 * cost_factor - w3 * safety_penalty


def _origin_matches(candidate: Itinerary, requested_origin: str) -> float:
    """Return 1.0 if candidate starts at the requested origin, 0.0 otherwise."""
    if not candidate.legs:
        return 0.0
    first_leg_origin = candidate.legs[0].from_
    if first_leg_origin == requested_origin:
        return 1.0
    return 0.0


def generate_candidates(
    origin: str,
    destination: str,
    max_budget_inr: int,
) -> List[Itinerary]:
    """
    Generate multimodal candidate itineraries using a custom weighted
    Dijkstra/A* over the curated transit dataset (PostGIS).

    For demo scope, we return a small static set of pre-computed candidates
    matching the 2 locked Kolkata routes, so the route planner can score
    them without a live API dependency.

    In a full implementation, this would query PostGIS for actual paths.
    """
    candidates = []

    # Route 1: Howrah → Salt Lake Sector V (train + auto)
    # Kolkata time = UTC+5:30, so 08:15 local = 02:45 UTC
    dep_utc_1 = datetime(2026, 8, 25, 2, 45, 0, tzinfo=UTC)  # 08:15 Kolkata
    candidates.append(
        Itinerary(
            total_cost_inr=50,
            total_time_minutes=55,
            legs=[
                Leg(
                    leg_index=1,
                    mode="train",
                    from_="Howrah Junction",
                    to="Sealdah Station",
                    scheduled_departure=dep_utc_1,
                    cost_inr=10,
                    travel_time_minutes=30,
                ),
                Leg(
                    leg_index=2,
                    mode="auto",
                    from_="Sealdah Station",
                    to="Salt Lake Sector V",
                    scheduled_departure=datetime(2026, 8, 25, 3, 0, 0, tzinfo=UTC),  # 09:00 Kolkata
                    cost_inr=40,
                    travel_time_minutes=25,
                ),
            ],
        )
    )

    # Route 2: Sealdah → Park Street (walk + metro)
    # 08:30 local = 03:00 UTC
    dep_utc_2 = datetime(2026, 8, 25, 3, 0, 0, tzinfo=UTC)  # 08:30 Kolkata
    candidates.append(
        Itinerary(
            total_cost_inr=30,
            total_time_minutes=90,
            legs=[
                Leg(
                    leg_index=1,
                    mode="walk",
                    from_="Sealdah Station",
                    to="Esplanade Metro",
                    scheduled_departure=dep_utc_2,
                    cost_inr=5,
                    travel_time_minutes=20,
                ),
                Leg(
                    leg_index=2,
                    mode="metro",
                    from_="Esplanade",
                    to="Park Street",
                    scheduled_departure=datetime(2026, 8, 25, 3, 30, 0, tzinfo=UTC),  # 09:30 Kolkata
                    cost_inr=25,
                    travel_time_minutes=70,
                ),
            ],
        )
    )

    return candidates


def pick_best_itinerary(
    origin: str,
    destination: str,
    max_budget_inr: int,
    safety_penalty: float = 0.0,
) -> Optional[Itinerary]:
    """
    Generate candidates and pick the highest-scoring one under budget.

    Returns None if no candidate fits under the budget ceiling.
    If no candidate has a matching origin, returns None explicitly.
    """
    candidates = generate_candidates(origin, destination, max_budget_inr)

    best: Optional[Itinerary] = None
    best_score = -float("inf")

    for candidate in candidates:
        score = utility_score(candidate, max_budget_inr, safety_penalty=safety_penalty)
        # Penalize candidates whose origin doesn't match the requested origin
        origin_factor = _origin_matches(candidate, origin)
        score = score * origin_factor  # If origin doesn't match, score becomes -inf or 0
        # When origin_factor is 0.0 and score is negative, the product is 0.0,
        # which is > -inf but we want to reject it. Let's handle this explicitly.
        if origin_factor == 0.0:
            # Check if there are any candidates with matching origin
            # We'll track this separately
            pass
        if score > best_score:
            best_score = score
            best = candidate

    # If the best candidate doesn't have matching origin, return None
    if best is not None and _origin_matches(best, origin) == 0.0:
        # Check if any candidate has matching origin
        for candidate in candidates:
            if _origin_matches(candidate, origin) == 1.0:
                return candidate
        return None

    return best