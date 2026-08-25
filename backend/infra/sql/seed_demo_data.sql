-- Seed data for Kolkata demo routes
-- Route 1: Howrah → Salt Lake Sector V (train + auto)
-- Route 2: Sealdah → Park Street (metro walk)

-- Safety zones around plausible transit paths in Kolkata
INSERT INTO safety_zones (zone_name, geom, source, confidence) VALUES
('College Street Area', 'SRID=4326;POLYGON((88.352 22.580, 88.358 22.580, 88.358 22.585, 88.352 22.585, 88.352 22.580))', 'demo_manual', 0.8),
('Howrah Station Surroundings', 'SRID=4326;POLYGON((88.356 22.600, 88.362 22.600, 88.362 22.608, 88.356 22.608, 88.356 22.600))', 'demo_manual', 0.7),
('Salt Lake Sector V Commercial', 'SRID=4326;POLYGON((88.420 22.650, 88.426 22.650, 88.426 22.655, 88.420 22.655, 88.420 22.650))', 'demo_manual', 0.8);

-- Amenities near Salt Lake Sector V
INSERT INTO amenities (name, category, price_inr, distance_km, geom, description, source) VALUES
('Express Meal Center', 'budget_food', 70, 0.3, 'SRID=4326;POINT(88.420 22.650)', 'Popular local snacks', 'demo_curated'),
('Urban Travel Hostel', 'budget_stay', 4800, 0.6, 'SRID=4326;POINT(88.418 22.648)', 'Near Salt Lake, shared rooms', 'demo_curated'),
('Street Food Corner', 'budget_food', 50, 0.4, 'SRID=4326;POINT(88.422 22.652)', 'Pani puri and local favorites', 'demo_curated'),
('Paying Guest Hostel', 'budget_stay', 3500, 1.2, 'SRID=4326;POINT(88.415 22.645)', 'Near college, shared facilities', 'demo_curated'),
('Coffee Day', 'budget_food', 80, 0.5, 'SRID=4326;POINT(88.421 22.651)', 'Coffee and light bites', 'demo_curated');

-- Route 1: Howrah → Salt Lake Sector V (2 legs)
-- Leg 1: Train from Howrah Junction to Sealdah Station
INSERT INTO itinerary_legs (trip_id, leg_index, mode, from_name, to_name, scheduled_departure, cost_inr, status) VALUES
('00000000-0000-0000-0000-000000000001', 1, 'train', 'Howrah Junction', 'Sealdah Station', '2026-08-25 08:15:00+05:30', 10, 'planned');

-- Leg 2: Auto from Sealdah Station to Salt Lake Sector V
INSERT INTO itinerary_legs (trip_id, leg_index, mode, from_name, to_name, scheduled_departure, cost_inr, status) VALUES
('00000000-0000-0000-0000-000000000001', 2, 'auto', 'Sealdah Station', 'Salt Lake Sector V', '2026-08-25 09:00:00+05:30', 40, 'planned');

-- Total: ₹50, 55 minutes for Route 1

-- Route 2: Sealdah → Park Street (walk + metro)
-- Leg 1: Walk from Sealdah to Esplanade Metro
INSERT INTO itinerary_legs (trip_id, leg_index, mode, from_name, to_name, scheduled_departure, cost_inr, status) VALUES
('00000000-0000-0000-0000-000000000002', 1, 'walk', 'Sealdah Station', 'Esplanade Metro', '2026-08-25 08:30:00+05:30', 5, 'planned');

-- Leg 2: Metro from Esplanade to Park Street
INSERT INTO itinerary_legs (trip_id, leg_index, mode, from_name, to_name, scheduled_departure, cost_inr, status) VALUES
('00000000-0000-0000-0000-000000000002', 2, 'metro', 'Esplanade', 'Park Street', '2026-08-25 09:00:00+05:30', 25, 'planned');

-- Total: ₹30, 90 minutes for Route 2