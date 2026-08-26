## 04_CONTRACTS.md — Frozen Contracts (Read Before Hour 1)

> **Why this file exists:** with 3 people and 16 hours, the only thing that kills you is two people building against different assumptions and discovering it at hour 12. Everything in this file is **frozen at Hour 0:45**. After that, a change here requires all three people to stop, agree, and update this file in the same commit.
>
> **Precedence:** this file > `05_FEATURE_SPECS.md` > `ARCHITECTURE.md` > `PRD.md` > anything said in chat. Where this file contradicts an earlier doc, that's deliberate — the resolution is recorded in §1.
>
> **Companion:** `05_FEATURE_SPECS.md` holds the algorithm-level specs for the three pitch-critical features (routing/presets, stay+food, cab handoff). This file defines the *shapes*; that file defines the *behaviour*.

---

## 1. Resolved Decisions (previously open / previously conflicting)

### 1.1 PRD.md §10 — Open Decisions, now closed

| # | Decision | Resolution | Rationale |
|---|---|---|---|
| D1 | Demo city + routes | **Kolkata.** Route 1: Howrah Junction → Salt Lake Sector V. Route 2: Sealdah → Park Street. | Every example in the project so far was Kolkata-specific. Two routes, not one — a judge will ask "try another one." Route 2 is deliberately short/simple as a fallback if Route 1 breaks on stage. |
| D2 | LLM provider order | **Groq primary, Gemini fallback.** | Groq's latency is what makes the <3s itinerary target in PRD §8 achievable. Gemini covers Groq rate-limit/outage. |
| D3 | Voice input | **Text-only in v1.** Mic button renders in the UI but `enabled: false` with a "coming soon" tooltip. | `speech_to_text` integration + accuracy tuning is 2+ hours that the agentic loop needs more. Feature is *disabled*, not deleted — the UI affordance still communicates the product vision to judges. |

### 1.2 CONFLICT-1 — Supabase vs. docker-compose Postgres

**The conflict:** `ARCHITECTURE.md` §6 declares `docker-compose: postgres + backend`. The later plan introduced Supabase for auth. Both cannot silently be "the database."

**Resolution — local dev on Docker, deployed on Supabase, one schema:**

- **Local dev (all 3 people, all 16 hours of building):** `docker-compose up` → `postgres:16` with the PostGIS extension. This is where every line of code is developed and tested. It is offline, fast, and resettable.
- **Deploy (Hour 12:30+, Person C):** Supabase project. Supabase runs Postgres and supports PostGIS via `create extension postgis;`. Same schema, same seed data.
- **How they stay identical:** there is **no ORM migration tool** (no Alembic — too much ceremony for 16 hours). There are exactly two SQL files, and both environments are built by running them in order:
  1. `infra/sql/01_schema.sql`
  2. `infra/sql/02_seed.sql`

  Person C runs these against Docker at Hour 1 and against Supabase at Hour 12:30. If they ever diverge, the fix is "re-run both files," not "hand-patch one side."
- **`ARCHITECTURE.md` §6 is therefore correct as written for dev** and gains a deploy target. No architectural change: the backend reads one `DATABASE_URL`, and which Postgres it points at is a config value, not a code path.

> **Hard rule:** nobody develops against Supabase. Supabase is a Hour-12:30 deployment concern only. If Supabase is down at hour 14, the demo still runs off Docker on Person C's laptop — that's the whole point of this split.

### 1.3 CONFLICT-2 — `X-User-Id` header vs. Supabase Auth JWT

**The conflict:** the API spec direction used a simple `X-User-Id` header. Supabase Auth issues JWTs. Person A can't write two auth systems and Person B can't wait for Supabase to exist before making the first API call.

**Resolution — one backend dependency, two modes, switched by env var:**

Person A writes exactly one function, `get_current_user_id()`, used as a FastAPI dependency on every protected route. Its behavior depends on `AUTH_MODE`:

| `AUTH_MODE` | Behavior | Used when |
|---|---|---|
| `header` (default in dev) | Reads `X-User-Id` header. If absent, returns the fixed dev UUID `00000000-0000-4000-8000-000000000001`. Never rejects. | Hours 0–12:30. Lets B and C hit the API with curl/Postman from minute one. |
| `supabase_jwt` | Reads `Authorization: Bearer <jwt>`, verifies signature against `SUPABASE_JWT_SECRET`, returns the `sub` claim. Rejects with 401 on invalid/missing. | Hour 12:30+ on the deployed backend. |

Person B's Dio interceptor attaches **both** headers unconditionally from Hour 2 onward:
- `X-User-Id: <local uuid>` — works immediately
- `Authorization: Bearer <supabase jwt>` — attached once Supabase auth lands, ignored by the backend until `AUTH_MODE` flips

This means **the auth switch at Hour 12:30 is a single env-var change on the server**, with zero client or backend code changes. Nobody is blocked, and nothing is thrown away.

**Supabase auth method:** anonymous sign-in (`signInAnonymously()`). No email, no password, no OTP, no verification screen. The user opens the app and already has a stable identity. Justification: PRD §3 personas are people who just arrived in a city — a signup wall before "help me get to my hostel" is the wrong product, *and* it saves ~90 minutes of build time. The anonymous user can be upgraded to a real account post-hackathon without a data migration, since the user UUID is stable.

### 1.4 Where the docs live

All `.md` spec files stay at the **repo root**, not in `docs/`. `AGENTS.md` §2 already declares the root-level layout, and OpenCode/Claude Code auto-read root-level `AGENTS.md`. Keeping root means zero cross-reference path edits and no drift between `AGENTS.md` §2 and reality. The three planning docs (`00_`–`04_`) live in `plan/` because they are for humans, not for the coding agent.

---

## 2. The Frozen Data Contract

Everything below is what Person A returns, Person B parses, and Person C seeds. If your code disagrees with this table, your code is wrong.

### 2.1 Core enums (exact string values — case-sensitive)

```
TransportMode  = "walk" | "bus" | "metro" | "train" | "auto" | "rideshare"
TripStatus     = "planning" | "active" | "completed" | "cancelled"
LegStatus      = "pending" | "in_progress" | "completed" | "skipped"
EventType      = "trip_created" | "leg_started" | "leg_completed"
               | "reroute" | "safety_alert" | "budget_switch" | "trip_completed"
Severity       = "info" | "warning" | "critical"
AmenityKind    = "stay" | "food"
```

### 2.2 `Trip` object

```json
{
  "trip_id": "uuid",
  "status": "active",
  "origin":      { "name": "Howrah Junction", "lat": 22.5839, "lng": 88.3425 },
  "destination": { "name": "Salt Lake Sector V", "lat": 22.5768, "lng": 88.4302 },
  "max_budget_inr": 200,
  "target_eta": "2026-08-25T10:00:00+05:30",
  "emergency_contact": { "name": "Ma", "phone": "+919XXXXXXXXX" },
  "total_cost_inr": 47,
  "total_duration_min": 68,
  "safety_score": 0.78,
  "legs": [ /* Leg[] */ ],
  "created_at": "2026-08-25T08:52:11+05:30"
}
```

### 2.3 `Leg` object

```json
{
  "leg_id": "uuid",
  "seq": 1,
  "mode": "train",
  "status": "pending",
  "from":  { "name": "Howrah Junction", "lat": 22.5839, "lng": 88.3425 },
  "to":    { "name": "Bidhannagar Road", "lat": 22.5885, "lng": 88.3990 },
  "cost_inr": 10,
  "duration_min": 22,
  "wait_min": 0,
  "depart_at": "2026-08-25T09:05:00+05:30",
  "arrive_at": "2026-08-25T09:27:00+05:30",
  "instruction": "Take the Howrah–Sealdah local, get off at Bidhannagar Road.",
  "polyline": [[22.5839, 88.3425], [22.5860, 88.3610], [22.5885, 88.3990]],
  "deep_link": null,
  "ride_options": [],
  "safety_score": 0.82
}
```

**`ride_options`** is `[]` for every mode except `auto` and `rideshare`, where it carries the cab handoff (`05_FEATURE_SPECS.md` §3.2):

```json
{ "provider": "rapido", "deep_link": "rapido://...",
  "web_fallback": "https://...", "est_inr": 95 }
```

`provider` ∈ `"uber" | "ola" | "rapido" | "gmaps"`. `deep_link` may be `null` (gmaps), `web_fallback` never is. `est_inr` is **our estimate**, may be `null` — B must label it "est." and never present it as a live fare quote.

**`wait_min`** is the time spent waiting for this leg's departure, from the time-dependent edge model (`05_FEATURE_SPECS.md` §1.3). `0` for on-demand modes (walk/auto/rideshare). B should show it when >0 — "12 min wait" is honest and it's what makes the cheaper-bus tradeoff legible.

**`polyline` is `[[lat, lng], ...]` — latitude first.** This is the single most common integration bug in map work; Mapbox's own GL JS uses `[lng, lat]`, so Person B must flip when handing coordinates to `mapbox_maps_flutter`. Written down here so it's flipped exactly once, in one place, in `dto/` mapping code.

### 2.4 `TripEvent` object (the SSE payload)

```json
{
  "event_id": "uuid",
  "trip_id": "uuid",
  "type": "reroute",
  "severity": "warning",
  "title": "Route updated",
  "message": "Bus 215A delayed 18 min. Switched to auto to protect your 10:00 ETA.",
  "created_at": "2026-08-25T09:31:04+05:30",
  "payload": { /* type-specific, see 2.5 */ }
}
```

### 2.5 `payload` shape per event type

| `type` | `payload` contents |
|---|---|
| `trip_created` | `{ "trip": Trip }` |
| `leg_started` / `leg_completed` | `{ "leg_id": uuid, "seq": int }` |
| `reroute` | `{ "reason": "delay"\|"budget", "old_legs": Leg[], "new_legs": Leg[], "cost_delta_inr": int, "eta_delta_min": int }` |
| `safety_alert` | `{ "zone_id": uuid, "zone_name": str, "location": {lat,lng}, "contact_notified": bool, "twilio_sid": str\|null, "map_link": str }` |
| `budget_switch` | `{ "leg_id": uuid, "from_mode": str, "to_mode": str, "saved_inr": int }` |
| `trip_completed` | `{ "total_cost_inr": int, "total_duration_min": int, "amenity_hint": {...}\|null }` |

`amenity_hint` (`05_FEATURE_SPECS.md` §2.3) is present only when arrival is after 21:00 with no return trip mentioned — the proactive stay suggestion: `{ "message": "Arriving 21:40. Want somewhere to stay?", "count": 3, "max_inr": 400, "radius_m": 900 }`. `null` otherwise, and B must handle `null`.

**Rule for Person B:** always render `title` + `message` (they are guaranteed present and human-readable). Only read `payload` for the three event types you have explicit UI for (`reroute`, `safety_alert`, `budget_switch`). Unknown event types must render as a generic info toast, never crash. This lets Person A add event types without breaking the client.

---

## 3. The Frozen API Contract

Base path: `/api/v1`. All bodies JSON. All timestamps ISO-8601 **with `+05:30` offset** (never naive, never UTC-without-offset — this has burned every hackathon team that skipped it).

| # | Method | Path | Purpose | Owner | Needed by B at |
|---|---|---|---|---|---|
| 1 | `POST` | `/trips` | NL text → planned trip | A | Hour 3:30 |
| 2 | `GET` | `/trips/{id}` | Fetch trip (client resync after backgrounding) | A | Hour 5 |
| 3 | `GET` | `/trips/{id}/events` | **SSE** live event stream | A | Hour 6:30 |
| 4 | `POST` | `/trips/{id}/start` | Mark trip active, start monitor loop | A | Hour 5 |
| 5 | `POST` | `/trips/{id}/simulate/delay` | **Demo trigger** — fire a delay → reroute | A | Hour 8 |
| 6 | `POST` | `/trips/{id}/simulate/zone-entry` | **Demo trigger** — fire geofence → SOS | A | Hour 10 |
| 7 | `POST` | `/trips/{id}/location` | Push current lat/lng (real geofence path) | A | Hour 10 |
| 8 | `GET` | `/amenities` | Budget + safety-aware stay/food (`05_FEATURE_SPECS.md` §2.4) | A | Hour 9:45 |
| 9 | `POST` | `/trips/{id}/sos` | Manual "I need help" button | A | Hour 10 |
| 10 | `GET` | `/health` | Liveness + which LLM is reachable | A | Hour 1 |

### 3.1 `POST /trips`

```jsonc
// request
{ "query": "Howrah se Salt Lake Sector V, ₹200 ke andar, 10 baje tak",
  "route_preference": "balanced",                                    // optional, see below
  "emergency_contact": { "name": "Ma", "phone": "+919XXXXXXXXX" } }  // optional

// 201 response
{ "trip": Trip, "parsed_intent": { /* what the LLM understood — show this in UI, it sells the AI */ },
  "route_preference_used": "safest",     // may differ from requested — see auto-suggest
  "preference_note": "It's late — I optimised for safety over speed.",   // null unless auto-suggested
  "clarification_needed": null }
```

**`route_preference`** ∈ `"balanced" | "fastest" | "cheapest" | "safest"`, default `"balanced"`. Weight sets in `05_FEATURE_SPECS.md` §1.6.

**Auto-suggest:** if departure is after 20:00 and the client sent no explicit preference, the server may override to `"safest"` and must then set both `route_preference_used` and a human-readable `preference_note`. B renders the note when present. This is the agent changing its own objective function based on context — worth surfacing, not hiding.

If the LLM can't determine origin or destination:

```jsonc
// 200 response (not an error!)
{ "trip": null, "parsed_intent": {...},
  "clarification_needed": { "field": "destination", "question": "Salt Lake ke kaunse part mein — Sector V ya Karunamoyee?" } }
```

Per PRD FR-1: **at most one** clarifying question, and never a silent failure.

### 3.2 `GET /trips/{id}/events` (SSE)

```
event: reroute
data: {"event_id":"...","type":"reroute",...}

event: heartbeat
data: {"ts":"2026-08-25T09:31:10+05:30"}
```

- Heartbeat every **15 s**. Non-negotiable: without it, mobile networks and proxies silently kill the connection and the "live" demo dies on stage.
- On connect, the server **replays all events for this trip** before streaming new ones. This makes the stream idempotent — Person B can reconnect freely, and a backgrounded app catches up automatically.
- Person B dedupes on `event_id`.

### 3.3 Error envelope (every 4xx/5xx, no exceptions)

```json
{ "error": { "code": "NO_ROUTE_UNDER_BUDGET",
             "message": "Cheapest route to Sector V is ₹47 over your ₹200 ceiling.",
             "detail": { "cheapest_inr": 247 } } }
```

Codes Person B must handle by Hour 11: `NO_ROUTE_UNDER_BUDGET`, `INTENT_UNPARSEABLE`, `TRIP_NOT_FOUND`, `LLM_UNAVAILABLE`, `INTERNAL`.

---

## 4. The Frozen Database Contract

Person C owns `01_schema.sql`. Person A codes SQLAlchemy models to match it. Table and column names below are final.

```
users              (id uuid pk, created_at)
trips              (id uuid pk, user_id fk, status, origin_name, origin_geom geography(Point,4326),
                    dest_name, dest_geom, max_budget_inr, target_eta timestamptz,
                    emergency_contact_name, emergency_contact_phone,
                    total_cost_inr, total_duration_min, safety_score, raw_query, parsed_intent jsonb,
                    created_at, started_at, completed_at)
legs               (id uuid pk, trip_id fk, seq int, mode, status,
                    from_name, from_geom, to_name, to_geom,
                    cost_inr, duration_min, depart_at, arrive_at, instruction,
                    polyline jsonb, deep_link, safety_score)
trip_events        (id uuid pk, trip_id fk, type, severity, title, message, payload jsonb, created_at)
transit_stops      (id uuid pk, name, geom geography(Point,4326), modes text[])
transit_routes     (id uuid pk, route_code, mode, from_stop_id fk, to_stop_id fk,
                    cost_inr, duration_min, headway_min, first_dep time, last_dep time, polyline jsonb)
safety_zones       (id uuid pk, name, geom geography(Polygon,4326), base_risk numeric,
                    night_multiplier numeric, notes)
amenities          (id uuid pk, name, kind, geom geography(Point,4326),
                    price_inr int, rating numeric, verified bool, phone, address)
simulated_delays   (id uuid pk, route_id fk, delay_min int, active bool, note)
```

Three things that will bite you if missed:

1. **`geography(Point,4326)`, not `geometry`.** With `geography`, `ST_Distance` returns metres directly — no projection maths, no unit bugs. Person A's radius queries assume metres.
2. **GIST indexes on every `geom` column.** `CREATE INDEX ON amenities USING GIST(geom);` Without them the amenity query is a table scan; with 40 seed rows nobody notices, and it's still the right habit.
3. **`polyline` is `jsonb`, storing `[[lat,lng],...]`** — same lat-first convention as §2.3.

---

## 5. Naming & Env Contract

Single `.env` at `backend/.env`, mirrored by a committed `backend/.env.example`. Person C owns the file; A and B consume it.

```bash
# --- database ---
DATABASE_URL=postgresql+asyncpg://raahi:raahi@localhost:5432/raahi

# --- llm (D2: groq primary, gemini fallback) ---
GROQ_API_KEY=
GROQ_MODEL=llama-3.3-70b-versatile
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.0-flash
LLM_TIMEOUT_S=8

# --- auth (CONFLICT-2) ---
AUTH_MODE=header                # header | supabase_jwt
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_JWT_SECRET=

# --- alerts ---
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM_NUMBER=
TWILIO_TO_NUMBER_OVERRIDE=      # trial-account safety valve, see Person C Phase 3
ALERTS_ENABLED=true

# --- agent thresholds (tune live during rehearsal) ---
DELAY_THRESHOLD_MIN=15
MONITOR_POLL_INTERVAL_S=5
GEOFENCE_BUFFER_M=50
SAFETY_SCORE_FLOOR=0.35
```

Flutter side gets **no `.env` with secrets**. Config comes in at build time:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=MAPBOX_TOKEN=pk.xxx \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxx
```

`10.0.2.2` is the Android emulator's route to the host's `localhost` (per `ARCHITECTURE.md` §6). iOS Simulator uses `localhost`. Physical device on the same Wi-Fi uses the host's LAN IP — **have this one ready before the demo**, since venue Wi-Fi often blocks device-to-laptop traffic and the fallback is a hotspot from your own phone.

---

## 6. Git Contract

- `main` is always demo-able. Nobody pushes a broken `main`.
- Branches: `a/<thing>`, `b/<thing>`, `c/<thing>`. Merge to `main` only at a sync point (see `00_MASTER_PLAN.md` §3).
- Conventional commits per `AGENTS.md` §4: `feat:`, `fix:`, `docs:`, `chore:`.
- **Files each person owns exclusively** (edit someone else's file → tell them in chat first):
  - A: `backend/app/**` except `data/` and `db/schema`
  - B: `mobile/**`
  - C: `infra/**`, `backend/app/data/**`, `backend/.env*`, `backend/app/services/twilio_client.py`
- At **Hour 14:30 the repo freezes.** After that: demo-blocking bugfixes only, no features, no refactors, no dependency upgrades. This rule has saved more demos than any amount of extra coding.

---

*Next: `00_MASTER_PLAN.md` for the timeline and sync points, then your own person-file.*