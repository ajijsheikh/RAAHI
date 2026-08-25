from pydantic import BaseModel, Field, validator
from typing import Optional, List, Dict, Any
from datetime import datetime


class Leg(BaseModel):
    leg_index: int = Field(..., description="1-based index within the trip")
    mode: str = Field(..., description="walk, bus, metro, train, auto, rideshare")
    from_: str = Field(..., alias="from", description="Origin name")
    to: str = Field(..., description="Destination name")
    scheduled_departure: datetime = Field(..., description="Scheduled departure time")
    cost_inr: int = Field(..., ge=0, description="Cost in Indian Rupees")

    @validator("mode")
    def mode_must_be_valid(cls, v: str) -> str:
        allowed = {"walk", "bus", "metro", "train", "auto", "rideshare"}
        if v not in allowed:
            raise ValueError(f"Mode must be one of {allowed}")
        return v


class ParsedIntent(BaseModel):
    origin: str = Field(..., description="Origin location")
    destination: str = Field(..., description="Destination location")
    max_budget_inr: int = Field(..., ge=50, le=5000, description="Maximum budget in INR")
    target_eta: Optional[datetime] = Field(None, description="Target arrival time")
    emergency_contact: Optional[str] = Field(None, description="Emergency contact phone")
    amenities_requested: Optional[List[str]] = Field(None, description="Requested amenity types")


class Itinerary(BaseModel):
    total_cost_inr: int = Field(..., ge=0, description="Total itinerary cost")
    total_time_minutes: int = Field(..., ge=0, description="Total travel time in minutes")
    legs: List[Leg] = Field(..., description="Ordered list of legs")


class TripCreate(BaseModel):
    query: str = Field(..., description="Raw natural language query")
    emergency_contact_phone: Optional[str] = Field(None, description="E.164 phone number")


class TripResponse(BaseModel):
    trip_id: str = Field(..., description="UUID of the created trip")
    status: str = Field(..., description="Trip status: planning, active, completed, cancelled")
    parsed_intent: ParsedIntent
    itinerary: Itinerary
    amenities: Dict[str, List[Dict[str, Any]]]  # {"budget_food": [...], "budget_stay": [...]}


class ClarificationResponse(BaseModel):
    trip_id: Optional[str] = Field(None, description="If trip was partially created")
    missing_field: str = Field(..., description="The field that needs clarification")
    current_partial: Optional[Dict[str, Any]] = Field(None, description="What was parsed so far")