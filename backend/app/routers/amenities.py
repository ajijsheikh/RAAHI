from fastapi import APIRouter, Query
from typing import Optional, List
from pydantic import BaseModel

from app.db.models import Amenity, get_db
from sqlalchemy import select, func
from sqlalchemy.orm import Session


router = APIRouter(tags=["amenities"])


class AmenityResponse(BaseModel):
    id: str
    name: str
    category: str
    price_inr: int
    distance_km: float
    description: Optional[str] = None
    source: str = "demo_curated"


@router.get("/amenities", response_model=List[AmenityResponse])
async def search_amenities(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    radius_km: Optional[float] = Query(2.0, description="Search radius in km"),
    category: Optional[str] = Query(None, description="'budget_food' | 'budget_stay'"),
):
    """Standalone amenity search (API_SPEC.md §6)."""
    db: Session = next(get_db())

    # Base query - in a real implementation, we'd use PostGIS ST_DWithin
    # For demo, we return all amenities and filter/sort client-side
    result = db.execute(select(Amenity))
    all_amenities = result.scalars().all()

    # Filter by category if specified
    if category:
        all_amenities = [a for a in all_amenities if a.category == category]

    # Sort by distance (we stored distance_km, so sort by that)
    all_amenities.sort(key=lambda a: a.distance_km)

    # Limit to 5 results
    results = all_amenities[:5]

    return [
        AmenityResponse(
            id=str(a.id),
            name=a.name,
            category=a.category,
            price_inr=a.price_inr,
            distance_km=a.distance_km,
            description=a.description,
            source=a.source,
        )
        for a in results
    ]