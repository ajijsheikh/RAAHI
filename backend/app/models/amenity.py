from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime


class AmenityResponse(BaseModel):
    id: str = Field(..., description="UUID of the amenity record")
    name: str = Field(..., description="Amenity name")
    category: str = Field(..., description="'budget_food' | 'budget_stay'")
    price_inr: int = Field(..., ge=0, description="Price in Indian Rupees")
    distance_km: float = Field(..., ge=0, description="Distance from reference point in km")
    description: Optional[str] = Field(None, description="One-line description")
    source: str = Field(default="demo_curated", description="Data source")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When the record was created")


class AmenitySearchFilters(BaseModel):
    radius_km: Optional[float] = Field(2.0, description="Search radius in km")
    category: Optional[str] = Field(None, description="'budget_food' | 'budget_stay'")
    query: Optional[str] = Field(None, description="Free text query for RAG path")