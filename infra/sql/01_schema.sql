CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE transit_stops (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL UNIQUE,
  geom geography(Point,4326) NOT NULL,
  modes text[] NOT NULL DEFAULT '{}'
);

CREATE TABLE transit_routes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  route_code text NOT NULL,
  mode text NOT NULL CHECK (mode IN ('walk','bus','metro','train','auto','rideshare')),
  from_stop_id uuid NOT NULL REFERENCES transit_stops(id),
  to_stop_id   uuid NOT NULL REFERENCES transit_stops(id),
  cost_inr int NOT NULL,
  duration_min int NOT NULL,
  headway_min int NOT NULL DEFAULT 15,
  first_dep time NOT NULL DEFAULT '05:00',
  last_dep   time NOT NULL DEFAULT '23:00',
  polyline jsonb NOT NULL DEFAULT '[]'
);

CREATE TABLE safety_zones (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  geom geography(Polygon,4326) NOT NULL,
  base_risk numeric NOT NULL CHECK (base_risk BETWEEN 0 AND 1),
  night_multiplier numeric NOT NULL DEFAULT 1.5,
  notes text
);

CREATE TABLE amenities (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('stay','food')),
  geom geography(Point,4326) NOT NULL,
  price_inr int NOT NULL,
  rating numeric,
  verified boolean NOT NULL DEFAULT false,
  phone text,
  address text
);

CREATE TABLE trips (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES users(id),
  status text NOT NULL DEFAULT 'planning',
  origin_geom geography(Point,4326),
  destination_geom geography(Point,4326),
  budget_inr int NOT NULL,
  target_eta timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

CREATE TABLE legs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id uuid NOT NULL REFERENCES trips(id),
  seq int NOT NULL,
  mode text NOT NULL CHECK (mode IN ('walk','bus','metro','train','auto','rideshare')),
  from_stop_id uuid REFERENCES transit_stops(id),
  to_stop_id   uuid REFERENCES transit_stops(id),
  cost_inr int NOT NULL,
  duration_min int NOT NULL,
  scheduled_departure time NOT NULL,
  polyline jsonb NOT NULL DEFAULT '[]',
  safety_score numeric NOT NULL DEFAULT 0.5
);

CREATE TABLE trip_events (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id uuid NOT NULL REFERENCES trips(id),
  event_type text NOT NULL,
  leg_index int,
  created_at timestamptz NOT NULL DEFAULT now(),
  message text,
  twilio_sid text,
  contact_notified boolean NOT NULL DEFAULT false
);

CREATE TABLE simulated_delays (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id uuid NOT NULL REFERENCES trips(id),
  leg_index int NOT NULL,
  active boolean NOT NULL DEFAULT false,
  delay_minutes int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON transit_stops USING GIST(geom);
CREATE INDEX ON safety_zones  USING GIST(geom);
CREATE INDEX ON amenities     USING GIST(geom);
CREATE INDEX ON trips (user_id, status);
CREATE INDEX ON legs (trip_id, seq);
CREATE INDEX ON trip_events (trip_id, created_at);

GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres;