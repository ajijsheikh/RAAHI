## 03_PERSON_C — Data, Infra, Auth, Alerts & Demo

> **You own:** Docker + Postgres/PostGIS, the SQL schema, all Kolkata seed data, Twilio, Supabase deploy, and the demo runsheet.
> **You do not own:** `backend/app/**` except `data/` and `twilio_client.py` (A owns the rest), `mobile/**` (B).
> **Read before starting:** `04_CONTRACTS.md` §1.2, §4, §5 (these are your spec), `00_MASTER_PLAN.md` §5, **`05_FEATURE_SPECS.md` §1.6 + §2.5 (your seed data has to make preset-switching and safety-aware amenity ranking visible — that's now a data requirement, not a nice-to-have)**.
> **Your files:** `infra/**`, `backend/app/data/**`, `backend/.env*`, `backend/app/services/twilio_client.py`.

**Your one job in one sentence:** make sure a real phone buzzes on stage, and that the demo can't be killed by bad Wi-Fi.

### Two things about your role

1. **Your Phase 1 is the single hardest deadline on the team.** A cannot build a route planner without route data. If you're not done by Hour 2:00, A stops working and helps you — that's already agreed in `00_MASTER_PLAN.md` §2. Say "I'm behind" out loud early; it's not a failure, it's the protocol.
2. **You have less code to write than A or B, and that's deliberate.** Your last two hours are demo logistics, which is real work that teams always forget and then lose the demo to.

---

## P0 — Foundation (Hour 0:00 → 2:00) ⚠️ THE CRITICAL PATH

### P0.1 — Repo + docker-compose (0:45 → 1:05)

You create the repo and give A and B push access. Then `infra/docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgis/postgis:16-3.4
    environment:
      POSTGRES_USER: raahi
      POSTGRES_PASSWORD: raahi
      POSTGRES_DB: raahi
    ports: ["5432:5432"]
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./sql:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U raahi"]
      interval: 5s
      retries: 10
volumes:
  pgdata:
```

Use the **`postgis/postgis` image, not plain `postgres`** — PostGIS is preinstalled and this saves a fiddly extension install. Files mounted at `/docker-entrypoint-initdb.d` run automatically in filename order on first boot, which is why the schema and seed files are numbered.

```bash
cd raahi/infra && docker compose up -d && docker compose logs -f postgres
```

**Reset command — write it on a sticky note, you'll use it a dozen times:**

```bash
docker compose down -v && docker compose up -d      # -v wipes the volume so init scripts re-run
```

Without `-v` your edited SQL won't re-run and you'll debug a phantom for 20 minutes.

### P0.2 — Schema (1:05 → 1:45) ⚠️ BLOCKS PERSON A

`infra/sql/01_schema.sql`, implementing `04_CONTRACTS.md` §4 **exactly** — those table and column names are frozen and A is writing SQLAlchemy models against them right now. If you need a change, tell A in chat *before* you write it.

```sql
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
  last_dep  time NOT NULL DEFAULT '23:00',
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

-- trips, legs, trip_events, simulated_delays: full column list per 04_CONTRACTS.md §4

CREATE INDEX ON transit_stops USING GIST(geom);
CREATE INDEX ON safety_zones  USING GIST(geom);
CREATE INDEX ON amenities     USING GIST(geom);
CREATE INDEX ON trips (user_id, status);
CREATE INDEX ON legs (trip_id, seq);
CREATE INDEX ON trip_events (trip_id, created_at);
```

Three things `04_CONTRACTS.md` §4 flagged, restated because they cause silent failures:

1. **`geography`, not `geometry`.** With `geography`, `ST_Distance` returns metres — A's radius queries assume metres. `geometry` returns degrees and every distance filter silently returns wrong results.
2. **GIST indexes on every `geom`.** Cheap, correct, and A's `ST_DWithin` geofence depends on them being the norm.
3. **`timestamptz`, never `timestamp`.** Everything in this project is `+05:30` (§3). Naive timestamps will make the ETA logic drift by 5.5 hours and it won't be obvious.

**DoD by 1:45 — tell A the moment this passes:**

```bash
docker compose exec postgres psql -U raahi -d raahi -c "\dt"
docker compose exec postgres psql -U raahi -d raahi -c "SELECT PostGIS_version();"
```

### P0.3 — `.env` + `.env.example` (1:45 → 2:00)

Create both from `04_CONTRACTS.md` §5 verbatim. Commit `.env.example`, **never `.env`** — add it to `.gitignore` first, then commit. Keys can be blank for now; you fill them in P1/P2.

Also confirm `.gitignore` covers: `.env`, `.venv/`, `mobile/build/`, `mobile/.dart_tool/`, `*.g.dart` is **not** ignored (B needs generated files committed for release builds... actually leave them generated locally, just don't fight about it).

---

## P1 — Kolkata Seed Data (Hour 2:00 → 4:00)

`infra/sql/02_seed.sql`. This is decision D1 from `04_CONTRACTS.md` §1.1 made concrete. Everything A's planner produces comes from this file — **realistic data here is what makes the demo credible.**

### P1.1 — Stops (2:00 → 2:30)

~12 stops covering both demo routes. Coordinates are approximate real Kolkata locations — good enough that the map looks right, and you should sanity-check each one on Google Maps as you go (a stop 2 km off makes your polyline cross the Hooghly at a strange angle and a local judge will notice).

```sql
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
```

**`ST_MakePoint(lng, lat)` — longitude FIRST.** Kolkata is lng ≈ 88.3–88.4, lat ≈ 22.5–22.6. If you swap them you get a point in Antarctica and every query silently returns nothing. Verify:

```sql
SELECT name, ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lng FROM transit_stops;
-- lat must be ~22.5x, lng must be ~88.3x. If reversed, you swapped the args.
```

### P1.2 — Routes (2:30 → 3:15) ⚠️ A NEEDS THIS BY 3:00

**Route 1 — Howrah → Sector V** (the main demo). Give the planner genuine choices, or "it picked the best one" is meaningless:

| From | To | Mode | ₹ | min | Note |
|---|---|---|---|---|---|
| Howrah Junction | Bidhannagar Road | train | 10 | 22 | cheap, the planner's default pick |
| Bidhannagar Road | Salt Lake Sector V | auto | 37 | 18 | last mile |
| Bidhannagar Road | Karunamoyee | bus | 12 | 20 | cheaper alternative |
| Karunamoyee | Salt Lake Sector V | auto | 20 | 8 | |
| Howrah Junction | Salt Lake Sector V | rideshare | 240 | 45 | **over ₹200 — must be rejected.** This row is what proves the hard budget constraint (`PRD.md` FR-2) is real. |
| Howrah Junction | Ultadanga | bus | 15 | 40 | reroute path after delay |
| Ultadanga | Salt Lake Sector V | auto | 45 | 15 | reroute path after delay |

**Route 2 — Sealdah → Park Street** (short fallback): Sealdah→Esplanade metro ₹10/12min, Esplanade→Park Street metro ₹5/4min, Esplanade→Park Street walk ₹0/14min, Sealdah→Park Street auto ₹60/18min.

Include the **`walk` ₹0 legs** — a ₹0 leg exercises B's UI formatting and A's cost maths in a way paid-only legs don't.

Every route needs a `polyline` as `[[lat,lng],...]` (**lat first** in the JSON — this is the app-layer convention from §2.3, opposite of `ST_MakePoint`; yes, it's confusing, which is exactly why both are written down). 3–5 points per route is plenty.

**Also set `headway_min`, `first_dep`, `last_dep` deliberately, not by default.** A's planner is time-dependent (`05_FEATURE_SPECS.md` §1.3) — it adds wait time from `headway_min` and excludes services outside their hours. So: trains `headway 20, 05:00–23:00`; buses `headway 12, 05:30–22:30`; metro `headway 7, 06:00–21:45`; auto/rideshare `headway 0, 00:00–23:59` (on-demand). This is what makes "the bus is technically cheaper but you'd wait 12 minutes" a real tradeoff the planner reasons about, and it's what makes a late-night query behave differently.

### P1.2b — Make the presets visibly different (3:15 → 3:25) ⚠️ NEW REQUIREMENT

`05_FEATURE_SPECS.md` §1.6 adds Fastest/Cheapest/Safest presets, and **they're only demoable if your data supports genuinely different answers.** Demo beat #4 is B tapping between them and the itinerary changing. If all three presets return the same route, the feature is invisible and unprovable.

So Route 1 needs three distinguishable paths — check each one after seeding:

| Preset should pick | Path | Why it wins |
|---|---|---|
| **Cheapest** | train ₹10 → bus ₹12 → auto ₹20 = **₹42**, ~62 min, safety 0.55 | lowest cost, most transfers |
| **Fastest** | train ₹10 → auto ₹37 = **₹47**, ~44 min, safety 0.45 | fewest minutes, but the auto leg clips a flagged zone |
| **Safest** | train ₹10 → bus ₹15 → auto ₹25 = **₹50**, ~58 min, safety 0.82 | avoids all flagged zones |

The Fastest path must pass through a flagged zone and the Safest path must avoid them — that's what makes the safety weighting produce a *different answer* rather than the same one. Adjust your zone polygons in P1.3 until this holds.

**Verify it yourself with A at P3.1** by calling `POST /trips` with each preset. If two presets return identical itineraries, fix the seed data — it's your call and it's much faster than changing A's algorithm.

**Critically: the reroute path must exist and be genuinely worse-but-viable.** When A's delay watcher fires, the planner needs an alternative that costs more or takes longer but still lands under ₹200 and before 10:00. If there's no alternative, the reroute demo silently does nothing — the #1 way this demo fails.

### P1.3 — Safety zones (3:25 → 3:50)

4–5 polygons. Two placement requirements, both load-bearing for demo beats:

1. **One must sit on Route 1's last-mile `auto` leg** — that's what makes the geofence demo fire on cue (beat #8).
2. **One must sit on the Fastest path but not the Safest path** (per P1.2b) — that's what makes preset switching produce different answers (beat #4).

```sql
INSERT INTO safety_zones (name, geom, base_risk, night_multiplier, notes) VALUES
 ('Under-lit stretch near Bidhannagar underpass',
  ST_GeomFromText('POLYGON((88.3960 22.5860, 88.4020 22.5860, 88.4020 22.5910, 88.3960 22.5910, 88.3960 22.5860))',4326)::geography,
  0.55, 1.6, 'Poor lighting, low footfall after 21:00'),
 ('Canal-side road, Beleghata', ..., 0.62, 1.7, 'Isolated after dark'),
 ('Howrah bridge approach — heavy crowd', ..., 0.35, 1.2, 'Pickpocket reports'),
 ('Sector V back lanes (post-office hours)', ..., 0.48, 1.8, 'Deserted after 20:00');
```

Polygon rings are `lng lat` pairs and **must close** (first point == last point) or PostGIS rejects them. Verify all zones are valid and roughly the right size:

```sql
SELECT name, ST_IsValid(geom::geometry), round(ST_Area(geom)) AS sq_m FROM safety_zones;
```

Aim for a few hundred metres across — a 5 km zone makes the whole route look unsafe and flattens the safety scoring.

**On framing:** these are illustrative demo data based on general "under-lit / low-footfall" reasoning, not verified incident reports. If a judge asks, say exactly that — and that production would source from Safetipin-style open data (`PRD.md` §7 already scopes crowdsourced data out). Don't claim real crime statistics you don't have.

### P1.4 — Amenities + verify (3:50 → 4:20) ⚠️ EXPANDED, RUNS PAST SYNC 1

**This sub-phase deliberately overruns SYNC 1 by 20 minutes.** Go to SYNC 1 at 4:00 with your stops/routes/zones done (that's what A needs), then finish the amenity rows during and right after the sync. P2.1 below starts at 4:20, not 4:00 — Twilio signup is mostly waiting on a verification SMS, so it has slack to give back.

`05_FEATURE_SPECS.md` §2.5 — this grew from ~10 rows to **~16**, because stay/food is a pitch point now (demo beat #6), and the *distribution* matters more than the count.

**8 stay** near Sector V and Park Street, ₹250–900, at least 5 `verified`. And the row that carries the whole feature:

> **At least one cheap stay must sit inside or adjacent to a flagged zone.**

A's amenity scorer weights walk-path safety at 0.30 for stays (§2.2). Without this row, a cheap-but-risky option never gets visibly demoted, and "safety-aware recommendations" is a claim you can't demonstrate. With it, the judge sees a ₹280 PG ranked *below* a ₹350 PG and the `reason` string explains why. Make it real: e.g. a ₹280 PG just off the Bidhannagar underpass zone.

**8 food**, ₹30–180, spread across the destination **and one mid-route transfer point (Bidhannagar Road)** — so `near=leg_end` returns something genuinely different from `near=destination`. Without the transfer-point rows, that distinction in A's API is untestable.

Fill `rating` on most rows and leave 2–3 null so B's UI handles missing ratings. Same for `phone` — B has a call button.

Then run every verification query above one final time and confirm `docker compose down -v && up -d` reproduces everything from scratch.

**DoD at SYNC 1:** A's `POST /trips` returns a real itinerary built from *your* data.

---

## P2 — Twilio (Hour 4:00 → 7:00)

The demo differentiator (`AGENTS.md` §3: this must never be mocked). Start early — account verification can be slow and you don't want to discover that at hour 9.

### P2.1 — Account + trial gotcha (4:20 → 4:50)

1. Sign up at twilio.com, free trial (~$15 credit).
2. Get a trial phone number (`TWILIO_FROM_NUMBER`).
3. **Verify the recipient number** under Phone Numbers → Verified Caller IDs.

**The gotcha that breaks demos:** a Twilio trial account can only send to **verified** numbers. Sending to an unverified number fails with error 21608 — and it will fail at hour 15 in front of judges if you didn't verify the demo phone.

So: **verify the actual second phone you'll hold up on stage, right now.** Then verify a backup number too (another teammate's). And put the demo number in `TWILIO_TO_NUMBER_OVERRIDE` (§5) so that regardless of what a judge types into the emergency-contact field, the SMS goes somewhere that actually works. That env var exists precisely for this.

### P2.2 — First SMS by hand (4:50 → 5:15)

Before writing any app code, prove the credentials work:

```bash
curl -X POST "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/Messages.json" \
  --data-urlencode "To=+919XXXXXXXXX" \
  --data-urlencode "From=$TWILIO_FROM_NUMBER" \
  --data-urlencode "Body=Raahi test" \
  -u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN"
```

If the phone buzzes, the hardest external dependency in the project is done. Fill the three keys into `.env` and tell A.

### P2.3 — `twilio_client.py` (5:15 → 6:15) ⚠️ A NEEDS THIS BY 8:45

`backend/app/services/twilio_client.py`. A calls this exact signature — don't change it without telling them:

```python
async def send_sos(to_phone: str, traveler_name: str,
                   lat: float, lng: float, zone_name: str) -> str | None:
    """Returns Twilio message SID, or None if ALERTS_ENABLED is false / send failed."""
```

Message body — keep it under 160 chars so it's one SMS segment, and lead with the actionable part:

```
RAAHI SOS: {traveler_name} entered a flagged area ({zone_name}) at {HH:MM}.
Live location: https://maps.google.com/?q={lat},{lng}
```

Requirements:
- **Async.** `AGENTS.md` §4 forbids blocking calls in handlers; the Twilio SDK is sync, so wrap it in `asyncio.to_thread()`.
- Honour `ALERTS_ENABLED` — if false, **log loudly at WARNING** and return `None`. Never silently pretend success (`AGENTS.md` §3).
- Honour `TWILIO_TO_NUMBER_OVERRIDE` — if set, send there instead of `to_phone`, and log both.
- Catch `TwilioRestException`, log the error code, return `None`. A's watcher still emits the in-app `safety_alert` with `contact_notified: false` — a failed SMS must never suppress the on-screen warning.
- Never log the auth token. Log the SID only.

### P2.4 — Buffer / finish seed data (6:15 → 7:00)

**The WhatsApp sandbox that used to live here is cut** (`05_FEATURE_SPECS.md` §4) — the expanded seed data in P1 is worth more than a second alert channel, and SMS working reliably beats WhatsApp working sometimes.

Use this slot for whatever P1 overran (the 16 amenity rows and the preset-differentiating routes take longer than they look), or as genuine buffer. You'll probably need it.

If you're somehow ahead: add the WhatsApp sandbox (`whatsapp:+14155238886`, recipient joins with a code). A WhatsApp message with a map preview does demo better than SMS. Strictly optional.

---

## P3 — Support + Deploy Prep (Hour 7:00 → 10:30)

Your build load is deliberately light here — A and B are in their hardest phases and you're the one with slack to help.

- **P3.1 (7:00→8:00) Tune the data with A.** Sit with A while the planner runs. Two specific checks, not just eyeballing:
  - Call `POST /trips` with each of the four presets. **If any two return identical itineraries, fix the seed data** (P1.2b) — that's your call and it's far faster than changing A's algorithm.
  - Fire a delay and confirm the reroute alternative actually exists and is worse-but-viable. If the reroute silently does nothing, the alternative path is missing or over budget.
- **P3.2 (8:00→8:45) Amenity data for `/amenities`.** Verify A's radius query returns sensible results. **Specifically check that the cheap-but-risky stay from P1.4 ranks below a pricier safe one** — if it doesn't, either the zone doesn't overlap the walk path or the price gap is too wide. This is demo beat #6 and it's your data that makes it work.
- **P3.3 (8:45→9:15) Hand Twilio to A** and watch the first end-to-end safety alert fire together.
- **P3.4 (9:15→10:30) Supabase project setup.** Create the project, note URL / anon key / JWT secret into `.env`. Run `create extension postgis;` then `01_schema.sql` + `02_seed.sql` in the SQL editor. Enable **anonymous sign-ins** in Auth settings (decision in `04_CONTRACTS.md` §1.2 — no email, no OTP). Don't point anything at it yet; per §1.2 **nobody develops against Supabase.**

---

## P4 — Deploy + Demo Prep (Hour 10:30 → 14:00)

- **P4.1 (10:30→12:00) Deploy the backend.** Render or Railway free tier, Docker deploy from `backend/`. Env vars: `DATABASE_URL` → Supabase connection string (use the **pooled** connection string, port 6543 — direct connections on port 5432 hit limits fast), plus LLM keys, Twilio keys, `AUTH_MODE=header` for now. **Timebox this to 90 minutes.** If it's fighting you, stop — laptop + hotspot is a completely legitimate demo setup and `00_MASTER_PLAN.md` §5 already lists it as backup #3.
- **P4.2 (12:00→12:45) Auth flip with A and B.** Set `AUTH_MODE=supabase_jwt` on the deployed backend, B calls `signInAnonymously()`, verify a real request passes. **If this isn't clean in 30 minutes, revert to `header` and move on** — it's a nice-to-have and reverting is one env var.
- **P4.3 (12:45→13:30) Write the demo runsheet card.** Take `00_MASTER_PLAN.md` §5, print it or put it in your notes app. Add the exact query string to type, exact tap order, and what to say if something fails ("that's the fallback path working as designed" — practise saying it calmly).
- **P4.4 (13:30→14:00) Backup everything.** `pg_dump` of the seeded DB into the repo. B's release APK on both phones. Verify the whole chain once on the deployed backend and once on the laptop.

---

## P5 — Lock & Own The Demo (14:30 → 16:00)

Repo frozen. This 90 minutes is yours and it's the most valuable time on the team.

- **14:30–15:15 — three consecutive clean runs.** Same phone, no restarts between runs. If run 2 or 3 fails where run 1 passed, you've found a state-leak bug (leftover monitor task, un-reset `simulated_delays`, duplicate SSE queue) — that's exactly the bug that kills demos, and finding it now is the whole point.
- **15:15–15:30 — record a screen capture of a full successful run.** Save it on the demo phone. **Do this even though everything is working.** It's backup #4 and it costs 4 minutes.
- **15:30–15:45 — physical checklist** (from `00_MASTER_PLAN.md` §5): both phones >80%, demo number verified in Twilio, hotspot on and tested, `ALERTS_ENABLED=true`, emulator warm, one dry run in the last 30 min.
- **15:45–16:00 — reset to a clean state and don't touch anything.** Clear `simulated_delays`, delete test trips, leave the app on the pre-filled Trip Request screen. Hands off the keyboard.

**Reset script — have it ready, you'll run it between every rehearsal:**

```sql
DELETE FROM trip_events; DELETE FROM legs; DELETE FROM trips;
UPDATE simulated_delays SET active = false;
```

---

## Your Handoffs — These Are The Team's Critical Path

| Hour | You give | To | What breaks if late |
|---|---|---|---|
| **1:45** | **schema applied to Docker Postgres** | **A** | **A is fully blocked. This is the hardest deadline on the team.** |
| 3:00 | stops + routes seeded | A | A's route planner has nothing to plan over; SYNC 1 fails |
| 3:25 | presets return 3 different routes (P1.2b) | A, B | Preset switching is invisible — demo beat #4 dies |
| 4:20 | 16 amenities incl. the cheap-but-risky stay | A | Safety-aware recommendations can't be demonstrated — beat #6 dies |
| 5:15 | Twilio keys verified in `.env` | A | Safety alert can't be real; the main differentiator is gone |
| 6:15 | `twilio_client.send_sos()` | A | A's safety watcher has no send path |
| 12:15 | Supabase URL + anon key | B | B skips anon auth (acceptable — nice-to-have) |
| 15:30 | working demo setup + backups | everyone | You demo off a laptop and hope |

## What You Need From Others

| Hour | You need | From | If it's late |
|---|---|---|---|
| 8:45 | A's safety watcher ready to call your client | A | Test `send_sos()` standalone with a Python one-liner |
| 15:00 | release APK | B | Demo from the debug build — works, just janky |