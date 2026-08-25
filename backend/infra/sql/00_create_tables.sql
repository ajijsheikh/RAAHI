-- 01_create_trips_table.sql
CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL DEFAULT gen_random_uuid(),
    status VARCHAR(20) NOT NULL DEFAULT 'planning',
    query_text TEXT NOT NULL,
    max_budget_inr INTEGER NOT NULL,
    target_eta TIMESTAMPTZ,
    emergency_contact_phone VARCHAR(20),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- 02_create_itinerary_legs_table.sql
CREATE TABLE itinerary_legs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    leg_index INTEGER NOT NULL,
    mode VARCHAR(20) NOT NULL,
    from_name TEXT NOT NULL,
    to_name TEXT NOT NULL,
    scheduled_departure TIMESTAMPTZ NOT NULL,
    actual_arrival TIMESTAMPTZ,
    cost_inr INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'planned'
);

-- 03_create_trip_events_table.sql
CREATE TABLE trip_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    event_type VARCHAR(30) NOT NULL,
    trigger_reason VARCHAR(30),
    leg_index INTEGER,
    old_leg JSONB,
    new_leg JSONB,
    message TEXT NOT NULL,
    twilio_sid VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 04_create_safety_zones_table.sql
CREATE TABLE safety_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_name TEXT NOT NULL,
    geom GEOMETRY(Polygon, 4326) NOT NULL,
    source VARCHAR(50) NOT NULL DEFAULT 'demo_manual',
    confidence REAL NOT NULL DEFAULT 1.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 05_create_amenities_table.sql
CREATE TABLE amenities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category VARCHAR(20) NOT NULL,
    price_inr INTEGER NOT NULL DEFAULT 0,
    distance_km REAL NOT NULL DEFAULT 0.0,
    geom GEOMETRY(Point, 4326),
    description TEXT,
    source VARCHAR(50) NOT NULL DEFAULT 'demo_curated',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create PostGIS extension if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis;