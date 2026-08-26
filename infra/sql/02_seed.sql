-- Stops (12 covering both demo routes)
INSERT INTO transit_stops (name, geom, modes) VALUES
 ('Howrah Junction',       ST_MakePoint(88.3425, 22.5839)::geography, '{train,bus,auto}'),
 ('Bidhannagar Road',      ST_MakePoint(88.3990, 22.5885)::geography, '{train,bus,auto}'),
 ('Salt Lake Sector V',    ST_MakePoint(88.4302, 22.5768)::geography, '{bus,auto}'),
 ('Karunamoyee',           ST_MakePoint(88.4126, 22.5772)::geography, '{bus,auto}'),
 ('Sealdah Station',       ST_MakePoint(88.3703, 22.5675)::geography, '{train,metro,bus,auto}'),
 ('Esplanade',             ST_MakePoint(88.3520, 22.5645)::geography, '{metro,bus,auto}'),
 ('Park Street',           ST_MakePoint(88.3520, 22.5525)::geography, '{metro,bus,auto}'),
 ('Maidan',                ST_MakePoint(88.3450, 22.5570)::geography, '{metro,walk}'),
 ('Ultadanga',             ST_MakePoint(88.3950, 22.5950)::geography, '{train,bus,auto}'),
 ('Beleghata',             ST_MakePoint(88.3880, 22.5620)::geography, '{bus,auto}'),
 ('Dum Dum',               ST_MakePoint(88.4230, 22.6270)::geography, '{metro,train}'),
 ('Salt Lake Stadium',     ST_MakePoint(88.4020, 22.5690)::geography, '{metro,bus}');

-- Routes (Route 1: Howrah → Sector V with genuine choices)
-- Route 2: Sealdah → Park Street (short fallback)
INSERT INTO transit_routes (route_code, mode, from_stop_id, to_stop_id, cost_inr, duration_min, headway_min, first_dep, last_dep, polyline) VALUES
-- Route 1 legs
 ('R1_L1', 'train', (SELECT id FROM transit_stops WHERE name = 'Howrah Junction'), (SELECT id FROM transit_stops WHERE name = 'Bidhannagar Road'), 10, 22, 20, '05:00', '23:00', '[[22.5839,88.3425],[22.5800,88.3900],[22.5780,88.4100],[22.5768,88.4302]]'),
 ('R1_L2', 'auto',   (SELECT id FROM transit_stops WHERE name = 'Bidhannagar Road'), (SELECT id FROM transit_stops WHERE name = 'Salt Lake Sector V'), 37, 18, 0, '00:00', '23:59', '[[22.5800,88.3900],[22.5770,88.4150],[22.5768,88.4302]]'),
 ('R1_L3', 'bus',    (SELECT id FROM transit_stops WHERE name = 'Bidhannagar Road'), (SELECT id FROM transit_stops WHERE name = 'Karunamoyee'), 12, 20, 12, '05:30', '22:30', '[[22.5800,88.3900],[22.5750,88.4050],[22.5772,88.4126]]'),
 ('R1_L4', 'auto',   (SELECT id FROM transit_stops WHERE name = 'Karunamoyee'), (SELECT id FROM transit_stops WHERE name = 'Salt Lake Sector V'), 20, 8, 0, '00:00', '23:59', '[[22.5750,88.4050],[22.5730,88.4100],[22.5768,88.4302]]'),
 ('R1_L5', 'bus',    (SELECT id FROM transit_stops WHERE name = 'Howrah Junction'), (SELECT id FROM transit_stops WHERE name = 'Ultadanga'), 15, 40, 12, '05:30', '22:30', '[[22.5839,88.3425],[22.5880,88.3950],[22.5950,88.4100]]'),
 ('R1_L6', 'auto',   (SELECT id FROM transit_stops WHERE name = 'Ultadanga'), (SELECT id FROM transit_stops WHERE name = 'Salt Lake Sector V'), 45, 15, 0, '00:00', '23:59', '[[22.5880,88.3950],[22.5850,88.4100],[22.5768,88.4302]]'),
-- Route 2 legs
 ('R2_L1', 'metro', (SELECT id FROM transit_stops WHERE name = 'Sealdah Station'), (SELECT id FROM transit_stops WHERE name = 'Esplanade'), 10, 12, 7, '06:00', '21:45', '[[22.5675,88.3703],[22.5645,88.3520]]'),
 ('R2_L2', 'metro', (SELECT id FROM transit_stops WHERE name = 'Esplanade'), (SELECT id FROM transit_stops WHERE name = 'Park Street'), 5, 4, 7, '06:00', '21:45', '[[22.5645,88.3520],[22.5525,88.3520]]'),
 ('R2_L3', 'walk',  (SELECT id FROM transit_stops WHERE name = 'Esplanade'), (SELECT id FROM transit_stops WHERE name = 'Park Street'), 0, 14, 0, '06:00', '22:00', '[[22.5645,88.3520],[22.5550,88.3550],[22.5525,88.3520]]'),
 ('R2_L4', 'auto',  (SELECT id FROM transit_stops WHERE name = 'Sealdah Station'), (SELECT id FROM transit_stops WHERE name = 'Park Street'), 60, 18, 0, '00:00', '23:59', '[[22.5675,88.3703],[22.5600,88.3580],[22.5525,88.3520]]');

-- Safety zones (4 polygons - load-bearing for demo beats)
-- 1. Must sit on Route 1's last-mile auto leg (beat #8)
-- 2. Must sit on the Fastest path but not the Safest path (beat #4)
INSERT INTO safety_zones (name, geom, base_risk, night_multiplier, notes) VALUES
 ('Under-lit stretch near Bidhannagar underpass',
   ST_GeomFromText('POLYGON((88.3960 22.5860, 88.4020 22.5860, 88.4020 22.5910, 88.3960 22.5910, 88.3960 22.5860))',4326)::geography,
   0.55, 1.6, 'Poor lighting, low footfall after 21:00'),
 ('Canal-side road, Beleghata',
   ST_GeomFromText('POLYGON((88.3890 22.5630, 88.3950 22.5630, 88.3950 22.5680, 88.3890 22.5680, 88.3890 22.5630))',4326)::geography,
   0.62, 1.7, 'Isolated after dark'),
 ('Howrah bridge approach — heavy crowd',
   ST_GeomFromText('POLYGON((88.3430 22.5840, 88.3490 22.5840, 88.3490 22.5890, 88.3430 22.5890, 88.3430 22.5840))',4326)::geography,
   0.35, 1.2, 'Pickpocket reports'),
 ('Sector V back lanes (post-office hours)',
   ST_GeomFromText('POLYGON((88.4030 22.5700, 88.4090 22.5700, 88.4090 22.5750, 88.4030 22.5750, 88.4030 22.5700))',4326)::geography,
   0.48, 1.8, 'Deserted after 20:00');

-- Amenities (16 total: 8 stay + 8 food)
-- 8 stay near Sector V and Park Street, at least 5 verified
-- At least one cheap stay must sit inside or adjacent to a flagged zone
INSERT INTO amenities (name, kind, geom, price_inr, rating, verified, phone, address) VALUES
 ('Tech Serviced Stay', 'stay', ST_MakePoint(88.4280, 22.5740)::geography, 750, 4.2, true, '+91332658741', 'Sector V, Salt Lake'),
 ('Park Street Lodge', 'stay', ST_MakePoint(88.3510, 22.5510)::geography, 600, 4.0, true, '+91332458742', 'Park Street'),
 ('Budget Inn', 'stay', ST_MakePoint(88.3970, 22.5650)::geography, 350, 3.5, true, '+91332789456', 'Beleghata Road'),
 ('The Qube', 'stay', ST_MakePoint(88.4050, 22.5620)::geography, 280, 3.8, false, '+91332123456', 'Just off Bidhannagar underpass -- cheap but risky'),
 ('Swissôtel Kolkata', 'stay', ST_MakePoint(88.3990, 22.5650)::geography, 900, 4.5, true, '+91332654789', 'Sector V'),
 ('Hotel Pride', 'stay', ST_MakePoint(88.3500, 22.5530)::geography, 550, 4.1, true, '+91332332445', 'Park Street'),
 ('Zostel Kolkata', 'stay', ST_MakePoint(88.4310, 22.5750)::geography, 400, 3.9, true, '+91332998877', 'Salt Lake Sector V'),
 ('Lemon Tree Premier', 'stay', ST_MakePoint(88.3710, 22.5680)::geography, 800, 4.3, true, '+91332555666', 'Esplanade'),
 ('Food Court 1', 'food', ST_MakePoint(88.4300, 22.5770)::geography, 80, null, false, '+91332111111', 'Sector V food court'),
 ('Bhojohouse', 'food', ST_MakePoint(88.3990, 22.5880)::geography, 120, 4.0, true, '+91332222222', 'Bidhannagar Road'),
 ('Burger King', 'food', ST_MakePoint(88.3510, 22.5520)::geography, 150, 4.2, true, '+91332333333', 'Park Street'),
 (' Flurry''s', 'food', ST_MakePoint(88.3520, 22.5640)::geography, 100, 4.1, true, '+91332444444', 'Esplanade'),
 ('Oh! Calcutta', 'food', ST_MakePoint(88.3700, 22.5660)::geography, 200, 4.5, true, '+91332555777', 'Sealdah area'),
 ('China Town', 'food', ST_MakePoint(88.4000, 22.5630)::geography, 180, 3.8, false, '+91332666888', 'Salt Lake'),
 ('KFC', 'food', ST_MakePoint(88.3450, 22.5550)::geography, 100, 3.5, true, '+91332777888', 'Park Street area'),
 ('Fresh Juice Corner', 'food', ST_MakePoint(88.3880, 22.5610)::geography, 50, null, false, '+91332999888', 'Beleghata');