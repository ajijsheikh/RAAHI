from sqlalchemy import (
    create_engine, Text, Integer, DateTime, Boolean, JSON, ForeignKey, func,
    Column, MetaData, Time, ARRAY, String, Float
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base, registry

import os
import uuid
from datetime import datetime, timezone, time

from geoalchemy2 import Geography

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://raahi:rahi@localhost:5432/raahi"
)

async_engine = create_async_engine(DATABASE_URL, echo=False, pool_pre_ping=True)

AsyncSessionLocal = async_sessionmaker(async_engine, class_=AsyncSession, expire_on_commit=False)

engine = async_engine

Base = declarative_base()


# ─── Core tables per 04_CONTRACTS.md §4 ────────────────────────────────────

class Users(Base):
    __tablename__ = "users"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Trip(Base):
    __tablename__ = "trips"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    user_id = Column(PG_UUID(as_uuid=False), nullable=False)
    status = Column(Text, nullable=False)
    origin_name = Column(Text, nullable=False)
    origin_geom = Column(Geography("POINT", 4326), nullable=False)
    dest_name = Column(Text, nullable=False)
    dest_geom = Column(Geography("POINT", 4326), nullable=False)
    max_budget_inr = Column(Integer, nullable=False)
    target_eta = Column(DateTime(timezone=True), nullable=False)
    emergency_contact_name = Column(Text)
    emergency_contact_phone = Column(Text)
    total_cost_inr = Column(Integer)
    total_duration_min = Column(Integer)
    safety_score = Column(Float)
    raw_query = Column(Text)
    parsed_intent = Column(Text)  # stored as JSON string
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))


class ItineraryLeg(Base):
    __tablename__ = "legs"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    trip_id = Column(PG_UUID(as_uuid=False), ForeignKey("trips.id"), nullable=False)
    seq = Column(Integer, nullable=False)
    mode = Column(Text, nullable=False)
    status = Column(Text, nullable=False, default="pending")
    from_name = Column(Text, nullable=False)
    from_geom = Column(Geography("POINT", 4326), nullable=False)
    to_name = Column(Text, nullable=False)
    to_geom = Column(Geography("POINT", 4326), nullable=False)
    cost_inr = Column(Integer, nullable=False)
    duration_min = Column(Integer, nullable=False)
    depart_at = Column(DateTime(timezone=True), nullable=False)
    arrive_at = Column(DateTime(timezone=True), nullable=False)
    instruction = Column(Text)
    polyline = Column(JSONB, nullable=False, default="[]")
    deep_link = Column(Text)
    safety_score = Column(Float)


class TripEvent(Base):
    __tablename__ = "trip_events"
    __tablename__ = "trip_events"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    trip_id = Column(PG_UUID(as_uuid=False), ForeignKey("trips.id"), nullable=False)
    type = Column(Text, nullable=False)
    severity = Column(Text)
    title = Column(Text)
    message = Column(Text, nullable=False)
    payload = Column(JSONB, nullable=False, default="{}")
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class TransitStops(Base):
    __tablename__ = "transit_stops"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    name = Column(Text, unique=True, nullable=False)
    geom = Column(Geography("POINT", 4326), nullable=False)
    modes = Column(ARRAY(String), nullable=False, default=[])


class TransitRoutes(Base):
    __tablename__ = "transit_routes"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    route_code = Column(Text, nullable=False)
    mode = Column(Text, nullable=False)
    from_stop_id = Column(PG_UUID(as_uuid=False), ForeignKey("transit_stops.id"), nullable=False)
    to_stop_id = Column(PG_UUID(as_uuid=False), ForeignKey("transit_stops.id"), nullable=False)
    cost_inr = Column(Integer, nullable=False)
    duration_min = Column(Integer, nullable=False)
    headway_min = Column(Integer, nullable=False, default=15)
    first_dep = Column(Time, nullable=False, default=time(5, 0))
    last_dep = Column(Time, nullable=False, default=time(23, 0))
    polyline = Column(JSONB, nullable=False, default="[]")


class SafetyZone(Base):
    __tablename__ = "safety_zones"
    __tablename__ = "safety_zones"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    name = Column(Text, nullable=False)
    geom = Column(Geography("POLYGON", 4326), nullable=False)
    base_risk = Column(Float, nullable=False)
    night_multiplier = Column(Float, nullable=False, default=1.5)
    notes = Column(Text)


class Amenity(Base):
    __tablename__ = "amenities"
    __tablename__ = "amenities"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    name = Column(Text, nullable=False)
    kind = Column(Text, nullable=False)
    geom = Column(Geography("POINT", 4326), nullable=False)
    price_inr = Column(Integer, nullable=False)
    rating = Column(Float)
    verified = Column(Boolean, default=False)
    phone = Column(Text)
    address = Column(Text)


class SimulatedDelays(Base):
    __tablename__ = "simulated_delays"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    route_id = Column(PG_UUID(as_uuid=False), ForeignKey("transit_routes.id"), nullable=False)
    delay_min = Column(Integer, nullable=False)
    active = Column(Boolean, default=True)
    note = Column(Text)


# ─── Auxiliary tables ──────────────────────────────────────────────────────

class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=uuid.uuid4)
    phone_number = Column(Text, nullable=False)
    relation = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


# ─── Session helper ───────────────────────────────────────────────────────

async def get_db() -> AsyncSession:
    """Dependency to get DB session per request."""
    async with AsyncSessionLocal() as session:
        yield session