from sqlalchemy import create_engine, Column, UUID, Text, Integer, DateTime, Boolean, JSON, ForeignKey, func, Float
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
import os
import uuid
from datetime import datetime, timezone

from geoalchemy2 import Geography

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://raahi:rahi@localhost:5432/raahi"
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True, future=True)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine, future=True)

Base = declarative_base()


def get_db():
    """Dependency to get DB session per request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class Trip(Base):
    __tablename__ = "trips"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    user_id = Column(PG_UUID(as_uuid=False), nullable=False, default=uuid.uuid4)
    status = Column(Text, nullable=False, default="planning")
    query_text = Column(Text, nullable=False)
    max_budget_inr = Column(Integer, nullable=False)
    target_eta = Column(DateTime(timezone=True))
    emergency_contact_phone = Column(Text)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    completed_at = Column(DateTime(timezone=True))


class ItineraryLeg(Base):
    __tablename__ = "itinerary_legs"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    trip_id = Column(PG_UUID(as_uuid=False), ForeignKey("trips.id"), nullable=False)
    leg_index = Column(Integer, nullable=False)
    mode = Column(Text, nullable=False)
    from_name = Column(Text, nullable=False)
    to_name = Column(Text, nullable=False)
    scheduled_departure = Column(DateTime(timezone=True), nullable=False)
    actual_arrival = Column(DateTime(timezone=True))
    cost_inr = Column(Integer, nullable=False, default=0)
    status = Column(Text, nullable=False, default="planned")


class TripEvent(Base):
    __tablename__ = "trip_events"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    trip_id = Column(PG_UUID(as_uuid=False), ForeignKey("trips.id"), nullable=False)
    event_type = Column(Text, nullable=False)
    trigger_reason = Column(Text)
    leg_index = Column(Integer)
    old_leg = Column(JSON)
    new_leg = Column(JSON)
    message = Column(Text, nullable=False)
    twilio_sid = Column(Text)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class SafetyZone(Base):
    __tablename__ = "safety_zones"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    zone_name = Column(Text, nullable=False)
    geom = Column(Geography("POLYGON", srid=4326), nullable=False)
    source = Column(Text, nullable=False, default="demo_manual")
    confidence = Column(Float, nullable=False, default=1.0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class Amenity(Base):
    __tablename__ = "amenities"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    name = Column(Text, nullable=False)
    kind = Column(Text, nullable=False)
    price_inr = Column(Integer, nullable=False, default=0)
    geom = Column(Geography("POINT", srid=4326), nullable=False)
    rating = Column(Float)
    verified = Column(Boolean, default=False)
    phone = Column(Text)
    address = Column(Text)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    phone_number = Column(Text, nullable=False)
    relation = Column(Text)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))