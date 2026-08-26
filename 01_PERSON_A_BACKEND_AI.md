## 01_PERSON_A — Backend + AI Agents

> **You own:** FastAPI, LangGraph orchestration, all 5 agents, the LLM layer, the monitor loop, and the 10 endpoints in `04_CONTRACTS.md` §3.
> **You do not own:** SQL schema/seed (C), anything in `mobile/` (B), `twilio_client.py` internals (C writes it, you call it).
> **Read before starting:** `04_CONTRACTS.md` fully, **`05_FEATURE_SPECS.md` §1–3 (your algorithm spec — routing, amenities, cab handoff)**, `AGENTS.md` §0 + §3 + §4, `PRD.md` §6.
> **Your files:** `backend/app/**` except `data/` and `.env`.

**Your one job in one sentence:** make the agent visibly decide things by itself, twice, on cue, in under 2 seconds each time.

---

## P0 — Foundation (Hour 0:00 → 2:00)

### P0.1 — Repo + venv (0:45 → 1:00)

After SYNC 0 ends. Python 3.11 (not 3.12 — some LangGraph/pydantic wheels still lag).

```bash
cd raahi/backend
python3.11 -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install --upgrade pip
```

`requirements.txt` — pin these, don't float:

```
fastapi==0.115.6
uvicorn[standard]==0.34.0
pydantic==2.10.4
pydantic-settings==2.7.0
sqlalchemy[asyncio]==2.0.36
asyncpg==0.30.0
geoalchemy2==0.16.0
langgraph==0.2.60
groq==0.13.1
google-generativeai==0.8.3
twilio==9.4.1
httpx==0.28.1
python-dotenv==1.0.1
sse-starlette==2.1.3
pyjwt[crypto]==2.10.1
pytest==8.3.4
pytest-asyncio==0.25.0
black==24.10.0
ruff==0.8.4
```

```bash
pip install -r requirements.txt
```

**Why `sse-starlette`:** hand-rolling SSE in FastAPI means getting `Content-Type`, chunked encoding, and client-disconnect detection right. `EventSourceResponse` does all three and handles disconnect cleanup, which matters because your monitor loop must stop when the client vanishes.

### P0.2 — Hand B the mock fixture (1:00 → 1:15) ⚠️ BLOCKS PERSON B

**Do this before anything else in P0.** B is idle-blocked until they have it.

Write `backend/app/data/mock_trip.json` — a complete, realistic `Trip` per `04_CONTRACTS.md` §2.2 with **3 legs** (train → walk → auto, Howrah → Sector V), and a `mock_events.json` with one of each event type. Commit and tell B in chat.

Make the numbers real, not `"lorem"`: `cost_inr: 10 / 0 / 37`, plausible Kolkata coordinates, Hinglish instructions. B will build their entire UI against these values, and realistic data surfaces layout bugs (long instruction strings, ₹0 legs) that placeholder data hides.

**DoD:** B confirms in chat that they've pulled it.

### P0.3 — App skeleton + `/health` (1:15 → 1:45)

```
app/main.py           FastAPI app, CORS, router registration, lifespan
app/config.py         pydantic-settings Settings, reads .env
app/deps.py           get_db(), get_current_user_id()
app/routers/health.py
```

`get_current_user_id()` implements **CONFLICT-2 from `04_CONTRACTS.md` §1.3** — write both branches now, while it's a 10-line function, so the Hour-12:30 auth flip is a one-line env change:

```python
DEV_USER_ID = "00000000-0000-4000-8000-000000000001"

async def get_current_user_id(request: Request) -> str:
    if settings.AUTH_MODE == "header":
        return request.headers.get("X-User-Id") or DEV_USER_ID
    # supabase_jwt
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(401, ...)
    payload = jwt.decode(auth[7:], settings.SUPABASE_JWT_SECRET,
                         algorithms=["HS256"], audience="authenticated")
    return payload["sub"]
```

`GET /health` returns `{"status":"ok","db":true,"llm":{"groq":true,"gemini":true}}` — actually ping each provider with a 1-token request. At hour 13 when something's broken, this endpoint tells you *which* thing in 2 seconds.

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

`--host 0.0.0.0` matters: bound to `127.0.0.1` the Android emulator can't reach you via `10.0.2.2`. This costs teams 30 minutes at SYNC 1 every single time.

**DoD:** `curl localhost:8000/health` → all true.

### P0.4 — LLM client with fallback (1:45 → 2:00)

`app/services/llm_client.py`. `AGENTS.md` §3 requires a fallback — build it now, not later.

```python
async def complete_json(system: str, user: str, schema: dict) -> dict:
    """Groq primary, Gemini fallback. Raises LLMUnavailable if both fail."""
```

- Groq: `response_format={"type":"json_object"}`, model from `GROQ_MODEL`.
- Gemini: `generation_config={"response_mime_type":"application/json"}`.
- `asyncio.wait_for(..., timeout=settings.LLM_TIMEOUT_S)` on each. Groq timeout → immediately try Gemini. Both fail → raise `LLMUnavailable` → route returns `LLM_UNAVAILABLE` error envelope.
- Log which provider served each call. You'll want this when latency spikes at hour 13.

**Free-tier reality (`PRD.md` §9):** Groq free tier is roughly 30 req/min. Your demo makes ~2 LLM calls per trip. Fine — but **do not put an LLM call inside the monitor loop.** `ARCHITECTURE.md` §2 says watchers are deterministic threshold checks; a 5-second poll with an LLM call would burn your quota in 3 minutes and blow the latency budget.

**DoD:** unit-test the fallback by setting `GROQ_API_KEY` to garbage — Gemini should serve the call.

---

## P1 — Core Path (Hour 2:00 → 4:00)

### P1.1 — DB models matching C's schema (2:00 → 2:20)

`app/db/models.py`, SQLAlchemy 2.0 async, mirroring `04_CONTRACTS.md` §4 exactly. GeoAlchemy2 for geography columns:

```python
from geoalchemy2 import Geography
origin_geom: Mapped[str] = mapped_column(Geography("POINT", srid=4326))
```

Don't invent columns. If you need one, message C — they own the DDL.

### P1.2 — Intent Parser Agent (2:20 → 3:00)

`app/agents/intent_parser.py`. One agent, one file (`AGENTS.md` §4).

```python
async def parse_intent(raw_query: str, contact: dict | None) -> ParsedIntent
```

`ParsedIntent` (Pydantic): `origin_text`, `destination_text`, `max_budget_inr: int|None`, `target_eta: datetime|None`, `amenities_requested: list[str]`, `confidence: float`, `missing_fields: list[str]`.

System prompt requirements — write these in explicitly:

- **Hinglish and Bengali-English mixing must work.** "Howrah se Sector V, ₹200 ke andar, 10 baje tak" must parse. Give 3 few-shot examples in the prompt, at least two in Hinglish. This is the single highest-leverage prompt-engineering investment in the project — it's the first thing a judge types.
- Resolve relative times against a passed-in `now` in IST. "10 baje" → today 10:00 +05:30; if that's already past, tomorrow.
- Landmark aliases: "Howrah" → "Howrah Junction", "Sector V" → "Salt Lake Sector V", "Sealdah" → "Sealdah Station". Keep the alias map in Python, not the prompt — deterministic, testable, and it makes place-name matching against C's `transit_stops` reliable.
- Missing budget → `null`, not a guess. Missing origin or destination → add to `missing_fields`, which drives the single clarifying question in `PRD.md` FR-1.
- Output must be JSON only.

**Return `parsed_intent` in the API response** (`04_CONTRACTS.md` §3.1). Showing the judge what the model understood is a demo beat — step 2 of the runsheet depends on it.

**DoD:** 5 test queries parse correctly, including 2 Hinglish and 1 with a missing budget.

### P1.3 — Route Planner Agent (3:00 → 3:40)

**Read `05_FEATURE_SPECS.md` §1 in full before writing this.** It is the complete algorithm spec — time-dependent edges, two-stage k-shortest-paths, the diversity filter, and the scoring function. Summary of what you're building:

`app/agents/route_planner.py`. **Not an LLM call** — deterministic graph search over C's `transit_routes` (`ARCHITECTURE.md` §7).

```python
async def build_graph(db) -> Graph          # stops=nodes, routes=edges, + synthetic walk edges (§1.2)
def edge_traversal(edge, arrival_at_node)   # TIME-DEPENDENT — includes wait time (§1.3)
def find_candidates(graph, o, d, k=4)       # Yen's k-shortest + cheapest + safest, diversity-filtered (§1.4)
def score(it, budget, target_eta, weights)  # multi-objective (§1.5)
```

Three things from `05_FEATURE_SPECS.md` that are easy to skip and expensive to skip:

1. **Edge cost is time-dependent** (§1.3). A transit edge's real cost includes waiting for the next departure, and `first_dep`/`last_dep` must exclude services that aren't running. Skipping this gives you routes that are "faster" on paper but lose 25 minutes at bus stops — and a 10 PM query that returns "take the 6 AM local."
2. **Synthetic walk edges** (§1.2) — stops within 900 m get a free walk edge. One PostGIS query at graph-build time. This is what produces "get off here and walk 6 minutes" instead of forcing a paid last leg.
3. **The diversity filter** (§1.4) — reject candidates sharing >70% of edges with an accepted one. Without it, k=4 returns four near-identical routes and the preset switching in P1.3b has nothing to show.

The scoring function (§1.5) — this is what you explain if a judge asks "how does it decide?":

```python
def score(it, budget, target_eta, w):
    if it.total_cost_inr > budget:  return float("-inf")   # HARD, PRD FR-2
    if it.arrive_at > target_eta:   return float("-inf")   # HARD, misses the deadline
    cost_term     = 1 - (it.total_cost_inr / budget)
    time_term     = 1 - min(it.total_duration_min / 120, 1.0)
    transfer_term = 1 - min(it.transfers / 3, 1.0)
    safety_term   = it.safety_score                        # min across legs, NOT mean
    slack_term    = min((target_eta - it.arrive_at).minutes / 30, 1.0)
    return (w.cost*cost_term + w.time*time_term + w.transfer*transfer_term
            + w.safety*safety_term + w.slack*slack_term)
```

Two points worth defending on stage: **safety is `min()` across legs, never mean** (a route that's safe 90% of the way and terrifying for 10% is a terrifying route), and **`slack_term` rewards arriving early** (9:52 survives an 8-minute delay; 9:59 doesn't — and this is exactly what makes the delay watcher's trigger in P2.4 non-arbitrary).

**Leg safety score** via PostGIS: intersect each leg's polyline against `safety_zones`; `leg_safety = 1 - max(base_risk × night_multiplier_if_after_1900)`.

**If no candidate is under budget:** raise `NoRouteUnderBudget(cheapest_inr=...)` → `NO_ROUTE_UNDER_BUDGET` envelope. Never return the over-budget route. A judge *will* test this with ₹20.

**DoD — tests per `AGENTS.md` §5 and `05_FEATURE_SPECS.md` §1.8:** over-budget rejected · misses-ETA rejected · safest-preset beats faster-unsafe · service-hours edge excluded at 23:30 · diversity filter rejects near-duplicate. Five tests, ~60 lines total, and they're what you'll be asked about.

### P1.3b — Route presets (3:40 → 3:50)

`05_FEATURE_SPECS.md` §1.6. Four weight sets in `config.py` (`balanced` default, `fastest`, `cheapest`, `safest`), selected by a `route_preference` field on `POST /trips`. This is a dict lookup passed into `score()` — 10 minutes of work, and it's demo beat #4: tapping Fastest vs Safest and watching the itinerary actually change is what proves the scoring is real.

**Also add the auto-suggest** (§1.6): departure after 20:00 with no explicit preference → default to `safest` and say why in the response. An agent that changes its own objective function based on context is a stronger claim than one that just follows orders.

### P1.4 — `POST /trips` end-to-end (3:50 → 4:00)

Wire it: parse → resolve place names to stops → plan → score → persist trip+legs → emit `trip_created` event → return per `04_CONTRACTS.md` §3.1.

**DoD before SYNC 1:**

```bash
curl -X POST localhost:8000/api/v1/trips \
  -H 'Content-Type: application/json' \
  -d '{"query":"Howrah se Salt Lake Sector V, ₹200, 10 baje tak"}'
```

Returns a 3-leg itinerary under ₹200 in <3 s. **Take this curl to SYNC 1.**

---

## P2 — Live Loop (Hour 4:00 → 7:00)

### P2.1 — Trip state + `/start` + `GET /trips/{id}` (4:00 → 4:30)

`POST /trips/{id}/start` → status `active`, `started_at=now()`, spawn the monitor loop task. `GET /trips/{id}` returns the current Trip so a backgrounded client can resync.

### P2.2 — Event bus + SSE endpoint (4:30 → 5:30) ⚠️ BLOCKS PERSON B AT SYNC 2

`app/services/event_bus.py` — in-process `dict[trip_id, list[asyncio.Queue]]`. No Redis; single instance per `ARCHITECTURE.md` §6.

```python
async def publish(trip_id, event: TripEvent)   # persist to trip_events THEN fan out to queues
def subscribe(trip_id) -> asyncio.Queue
```

Persist-then-publish, in that order. That ordering is what makes replay-on-connect correct.

`GET /trips/{id}/events` with `EventSourceResponse`. Three things from `04_CONTRACTS.md` §3.2 that are not optional:

1. **Replay all persisted events on connect, before streaming new ones.** Makes the stream idempotent; B can reconnect freely.
2. **`heartbeat` every 15 s.** Without it, mobile networks silently drop the connection and your live demo dies mid-sentence.
3. **Clean up the queue on disconnect** (`try/finally`), or you leak a queue per reconnect.

**DoD:** `curl -N localhost:8000/api/v1/trips/<id>/events` streams; heartbeats visible; publishing from a `python -c` shell appears instantly.

### P2.3 — Monitor loop skeleton (5:30 → 6:15)

`app/agents/monitor_loop.py`. One `asyncio.Task` per active trip, polling every `MONITOR_POLL_INTERVAL_S` (5 s).

```python
async def monitor_trip(trip_id):
    while trip_is_active(trip_id):
        await check_delay(trip_id)     # P2.4
        await check_safety(trip_id)    # P3.2
        await check_budget(trip_id)    # P4.1
        await asyncio.sleep(settings.MONITOR_POLL_INTERVAL_S)
```

All three checks are **deterministic threshold comparisons — zero LLM calls** (`ARCHITECTURE.md` §2). Wrap each check in try/except and log-but-continue: one watcher throwing must never kill the loop, because a dead loop means a dead demo with no visible error.

### P2.4 — Delay watcher + `POST /simulate/delay` (6:15 → 7:00)

Watcher logic per `PRD.md` FR-3:

```
delay = lookup simulated_delays for current leg's route_id (active=true)
IF delay > DELAY_THRESHOLD_MIN AND (leg.arrive_at + delay) > next_leg.depart_at:
    → trigger replan (reason="delay")
```

Condition is "does this delay actually break my connection or ETA?", not just "is there a delay?" That distinction is the intelligence — a 20-minute delay with a 40-minute buffer needs no action, and *saying that on stage* is what separates a real agent from an if-statement.

`POST /trips/{id}/simulate/delay` (body: `{"delay_min": 18}`) inserts into `simulated_delays` and returns 202 immediately. **It must not perform the reroute itself** — it only plants the condition; the watcher discovers it on its next poll. That's what makes the demo honest: the reroute genuinely comes from the loop, and you can say "I'm not touching anything" truthfully.

**Emit `reroute` with `old_legs`, `new_legs`, `cost_delta_inr`, `eta_delta_min`** per `04_CONTRACTS.md` §2.5 — B needs the diff to animate the change.

**DoD at SYNC 2:** curl the simulate endpoint, watch the `reroute` event appear on the SSE stream within 5 s, unprompted.

---

## P3 — Autonomy (Hour 7:00 → 10:30)

### P3.1 — Replanner (7:00 → 7:45)

`replan(trip, reason, current_location)`: re-invoke the planner with current position as origin, same budget minus already-spent, same target ETA. Mark completed legs `completed`, replace pending ones. Persist, diff, publish.

Guards, both learned the hard way:
- **Max 3 reroutes per trip.** Prevents a flapping loop republishing forever mid-demo.
- If the new itinerary is materially identical (same modes, cost delta <₹5), **don't publish**. A "route updated — nothing changed" toast makes the agent look broken.

### P3.2 — Safety watcher + geofence (7:45 → 8:45)

```sql
SELECT id, name, base_risk FROM safety_zones
WHERE ST_DWithin(geom, ST_MakePoint(:lng,:lat)::geography, :buffer_m);
```

Note `ST_MakePoint(lng, lat)` — **PostGIS takes lng first**, while `04_CONTRACTS.md` §2.3 stores `[lat, lng]`. Get this backwards and your geofence silently never fires. Write a single helper and use it everywhere.

Trigger per `PRD.md` FR-3: zone entry (with 50 m buffer), or no location update for > 10 min while active. Fire **once per zone per trip** — dedupe in trip state, or you'll send 12 SMS in a minute and possibly get your Twilio trial throttled on stage.

`POST /trips/{id}/location` feeds real coordinates; `POST /trips/{id}/simulate/zone-entry` plants a location inside a seeded zone for the demo.

### P3.3 — Wire Twilio (8:45 → 9:05)

C writes `services/twilio_client.py` and exposes:

```python
async def send_sos(to_phone: str, traveler_name: str, lat: float, lng: float, zone_name: str) -> str  # returns SID
```

You call it from the safety watcher. Then emit `safety_alert` with `twilio_sid` and `contact_notified` per §2.5.

`AGENTS.md` §3: **never mock this path.** If `ALERTS_ENABLED=false`, log loudly and set `contact_notified: false` — don't silently pretend success. Also: catch Twilio exceptions and still emit the `safety_alert` event with `contact_notified: false`. A failed SMS must not swallow the in-app alert; the user still needs to know they're in a flagged zone.

### P3.4 — Manual SOS (9:05 → 9:15)

`POST /trips/{id}/sos` — same path, `severity: critical`, works regardless of zone (`PRD.md` FR-4 fallback button).

### P3.5 — Amenity agent (9:15 → 10:00) — CORE, not polish

**Read `05_FEATURE_SPECS.md` §2.** This moved out of P4 because it's a pitch point. `app/agents/amenity_agent.py` + `GET /amenities` per §2.4.

What makes it a feature rather than a nearby-places query — all three matter:

1. **Budget-aware:** filters on `budget_remaining` (ceiling minus already-spent), not the total budget. After a ₹47 trip on ₹200, the constraint is ₹153.
2. **Safety-aware:** `walk_path_safety()` — straight line from the route endpoint to the amenity, intersected against `safety_zones`. Reuses the exact same data as the routing safety score, which is a good architecture story: one dataset, two features.
3. **Route-aware:** `near=destination` for stay, `near=leg_end` for food (you eat at a transfer point, you sleep at the destination).

Scoring per §2.2 — same idiom as the route scorer, different weights per kind (stay weights safety 0.30 highest; food weights distance 0.35 highest). Hard filter on `price_inr > budget_remaining`, same discipline as routing.

**`reason` is a required response field, not decoration** (§2.4): one template-generated line per recommendation — *"Verified, ₹350, 8 min walk on a lit main road."* No LLM call, keep it deterministic. It's what turns a list into a recommendation, and it's what the judge reads out loud.

**Proactive hint** (§2.3): if `parse_intent` found arrival after 21:00 with no return trip, attach an `amenity_hint` to the `trip_completed` event — *"Arriving 21:40. Want somewhere to stay? 3 verified PGs under ₹400 within 900 m."* Nobody asked for it. That's the product. (First thing to cut inside this sub-phase if you're tight.)

### P3.6 — Cab deep links (10:00 → 10:30) — CORE, not polish

**Read `05_FEATURE_SPECS.md` §3.** `app/services/deep_links.py`. The `deep_link` field in `04_CONTRACTS.md` §2.3 currently always returns `null` — that's the gap this closes.

Populate `ride_options` on every `auto`/`rideshare` leg: Uber, Ola, Rapido native schemes + a Google Maps web fallback that always works. Return a **list**, sorted by `est_inr`, each with `deep_link` and `web_fallback` (§3.2).

`est_inr` comes from our own `transit_routes` cost for that leg. **Label it "est." and never present it as a live fare quote** — if asked, the honest answer is "our estimate from local fare data; the real quote comes from the provider on the next screen."

Scope framing for the pitch (§3.1): `PRD.md` §4 rules out in-app payments, and that stands. There's no free-tier programmatic ride-booking API in India — so we do what every real travel app does: deep-link handoff with the ride pre-filled, and the user confirms in the app that already has their card. Say it that way; it reads as a deliberate product boundary, not a gap.

**Connect it to the budget watcher** (§3.4): when P4.1's budget switch fires, re-populate `ride_options` with the cheaper providers so the event message becomes concrete — *"Auto would put you ₹40 over. Switched to bus — or tap for a Rapido bike at ₹95."* That's the difference between a booking button and an agent managing your budget across modes.

### P3.7 — Full-chain rehearsal (before SYNC 3)

Rehearse your half with curl: create trip → start → simulate delay → see reroute → simulate zone entry → **real phone buzzes**. Also verify `/amenities` returns sensible rows and one `auto` leg has populated `ride_options`. Arrive at SYNC 3 with this working.

---

## P4 — Polish (Hour 10:30 → 14:00)

Strictly in this order. Stop when the clock says stop. (Amenities and deep links moved to P3 — see `05_FEATURE_SPECS.md` §4.)

- **P4.1 Budget watcher (10:30→11:15).** Running cost > ceiling → greedy substitute cheaper mode (`auto`→`bus`/`shared auto`). Emit `budget_switch`, and re-populate `ride_options` per P3.6. On the cut list, but `ride_options` stays either way.
- **P4.2 Error envelopes (11:15→11:35).** One exception handler mapping to `04_CONTRACTS.md` §3.3. All 5 codes B expects. Timeboxed to 20 min — it's one handler.
- **P4.3 Auth flip support (11:35→12:05).** With C: set `AUTH_MODE=supabase_jwt` on the deployed backend, verify a real Supabase JWT passes. Nothing to write — you built it in P0.3. If it fights back for 20+ minutes, revert to `header` and move on.
- **P4.4 Hardening (12:05→14:00).** Run the demo chain 5× yourself. Watch for: leaked monitor tasks after trip completion, SSE queue growth on reconnect, duplicate events, timezone drift (everything `+05:30`), and preset switching returning identical itineraries (that means the diversity filter or the seed data needs work — talk to C).

---

## P5 — Lock (14:30 → 16:00)

Repo frozen. You are on-call for demo-blocking only. Have ready: your curl one-liners in a scratch file, `/health` open in a terminal, and the ability to restart the backend in <10 s.

---

## Your Handoffs — Don't Miss These

| Hour | You give | To | What breaks if late |
|---|---|---|---|
| 1:15 | `mock_trip.json` + `mock_events.json` | B | B is idle-blocked, loses 3 hours |
| 4:00 | working `POST /trips` | B | SYNC 1 fails |
| 7:00 | working SSE stream | B | SYNC 2 fails, live demo has no path |
| 8:45 | safety watcher ready to call `send_sos` | C | Twilio integration slips past SYNC 3 |

## What You Need From Others

| Hour | You need | From | If it's late |
|---|---|---|---|
| 2:00 | schema applied to Docker Postgres | C | **Stop your work and help C.** You cannot proceed. |
| 3:00 | Kolkata seed: stops + routes | C | Hand-insert 4 stops + 3 routes to unblock yourself, swap in C's real data at SYNC 1 |
| 3:25 | presets return 3 different routes (P1.2b) | A, B | Preset switching is invisible — demo beat #4 dies |
| 8:45 | `twilio_client.send_sos()` | C | Write the call site against the signature above; it'll work when C lands the file |