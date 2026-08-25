from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime


class EmergencyContactCreate(BaseModel):
    phone_number: str = Field(..., description="Phone number in E.164 format, e.g. +919800000000")
    relation: Optional[str] = Field(None, description="Relation to user, e.g. parent, spouse, friend")

    @validator("phone_number")
    def must_be_e164(cls, v: str) -> str:
        if not v.startswith("+"):
            raise ValueError("Phone number must be in E.164 format starting with +")
        if len(v) < 10:
            raise ValueError("Phone number too short")
        return v


class EmergencyContactResponse(BaseModel):
    id: str = Field(..., description="UUID of the contact record")
    phone_number: str = Field(..., description="E.164 phone number")
    relation: Optional[str] = Field(None, description="Relation to user")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="When the contact was registered")