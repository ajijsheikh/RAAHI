from fastapi import APIRouter, Body, HTTPException, status, Depends
from pydantic import BaseModel, Field, validator
from typing import Optional
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Base, engine
from app.db import get_db
from app.models.emergency_contact import EmergencyContactCreate, EmergencyContactResponse


router = APIRouter(tags=["emergency-contacts"])


class EmergencyContactRegister(BaseModel):
    phone_number: str = Field(
        ..., description="Phone number in E.164 format, e.g. +919800000000"
    )
    relation: Optional[str] = Field(
        None, description="Relation to user, e.g. parent, spouse, friend"
    )

    @validator("phone_number")
    def must_be_e164(cls, v: str) -> str:
        if not v.startswith("+"):
            raise ValueError("Phone number must be in E.164 format starting with +")
        if len(v) < 10:
            raise ValueError("Phone number too short")
        return v


@router.post(
    "/emergency-contacts",
    response_model=EmergencyContactResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_emergency_contact(
    payload: EmergencyContactRegister,
    db: Session = Depends(get_db),
):
    """Register/update emergency contact (API_SPEC.md §7)."""
    from app.db.models import EmergencyContact  # assuming we add this model

    # Check if table exists, create if not
    Base.metadata.create_all(bind=engine)

    # Use the EmergencyContact ORM model
    contact = EmergencyContact(
        phone_number=payload.phone_number,
        relation=payload.relation,
    )
    db.add(contact)
    db.commit()
    db.refresh(contact)

    return EmergencyContactResponse(
        id=contact.id,
        phone_number=contact.phone_number,
        relation=contact.relation,
        created_at=contact.created_at,
    )