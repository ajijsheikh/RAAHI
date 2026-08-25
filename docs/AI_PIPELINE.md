## AI_PIPELINE.md — Intent Parser, Utility Scoring & Monitoring

> **Purpose of this doc:** the internals of the AI agents — how user text gets parsed, how itineraries are scored and ranked, and how the monitor loop's three watchers operate.

---

## 1. Intent Parser (NL → Structured JSON)

**Goal:** Convert the user's free-text trip request into a deterministic JSON structure the back-end can work with.

### 1.1 Prompt Design
- The LLM call uses **function calling** (structured output), never a free-form text response that gets `eval`'d or interpolated into SQL/shell.
- System prompt contains only reusable constraints; user text is passed as a user-turn only — no system-prompt injection surface.
- Output schema is a fixed Pydantic model (backend) / freezed schema (frontend) with all required fields: `origin`, `destination`, `max_budget_inr`, `target_eta`, `emergency_contact` (optional), `amenities_requested[]` (optional).

### 1.2 Post-Parse Validation
- extracted `max_budget_inr` is re-validated: must be positive, must not be absurdly high/low (e.g. reject < 50 or > 5000 INR for demo city).
- extracted `target_eta` is validated as a future datetime, not past.
- if any required field is missing or invalid → return `422` with `clarification_needed` indicating the single most important missing field (per PRD.md FR-1, at most one clarifying question asked).

### 1.3 LLM Provider Order
- **Primary:** Groq (Llama 3.1 8B/70B) — fastest inference for <3s cold-start target.
- **Fallback:** Gemini 1.5 Flash — if Groq fails or exceeds rate limit, automatically switch.
- Both providers wrapped in a unified `llm_client.py` that returns the same structured schema regardless of which provider served the call.

---

## 2. Utility Scoring & Route Planning

**Goal:** Given structured intent + available modes, rank candidate itineraries and pick the best one that respects the budget ceiling.

### 2.1 Candidate Generation
- Route Planner generates multimodal candidates (walk → bus → metro → train → auto → rideshare deep-link) using a **custom weighted Dijkstra/A*** over the curated transit dataset (see DATABASE.md §3).
- Each candidate is a sequence of legs, each with: `mode`, `from`, `to`, `scheduled_departure`, `cost_inr`, `travel_time_minutes`.

### 2.2 Utility Function
Each candidate receives a score:

```
score = w1 * (1 / travel_time) - w2 * (cost / max_budget) - w3 * (safety_penalty)
```

where:
- `w1, w2, w3` are tunable weights (default: w1=0.5, w2=0.3, w3=0.2)
- `travel_time` = total minutes of the candidate
- `cost` = total cost of the candidate
- `safety_penalty` = sum of flagged-zone weights traversed by the candidate route (0 if none)

**Constraints:**
- If `cost > max_budget_inr`, the candidate is **automatically disqualified** (score = -∞), never returned to user.
- If no candidate is under budget → return explicit "no route under budget" message with the cheapest available option's cost (per FR-2, API_SPEC.md §1 `409` response).

### 2.3 Score Normalization & Tie-breaking
- If two candidates have identical scores, tie-break on: (1) fewer transfers, (2) faster ETA to target, (3) lower cost.

---

## 3. Monitor Loop — Three Watchers

The monitor loop runs for the duration of an active trip. It is initiated by the Orchestrator after trip creation (ARCHITECTURE.md §3 step 8). Each watcher is a **deterministic poller** — no LLM call on every tick.

### 3.1 Delay Watcher
- **Poll source:** simulated event table in Postgres (not a live transit API). The demo controls which legs have delays and when they fire, so the judge can trigger them on cue.
- **Poll logic:** every N seconds (configurable, demo default = 10s), check if the active leg's scheduled arrival has been postponed.
- **Trigger condition:** delay > `delay_threshold_minutes` (default 15 min) AND the delayed leg is a connecting leg (i.e. there's a next leg at risk of being missed).
- **Action:** call orchestrator with `replan_needed = true, reason = "delay", leg_id = X`. The orchestrator re-invokes the Route Planner Agent with the current position as new origin, same budget/ETA constraints.
- **Demo fireable endpoint:** `POST /trips/{trip_id}/simulate-delay` (API_SPEC.md §4).

### 3.2 Safety Watcher
- **Input:** current GPS coordinates (from Flutter `geolocator` package) + PostGIS `safety_zones` table.
- **Poll logic:** every N seconds (configurable, demo default = 5s), check if the user's point is inside any flagged polygon via `ST_Contains(zone_geom, point)`.
- **Trigger condition:** user's position crosses into a zone that was **not** in the previous poll but is in the current poll (i.e. geofence entry).
- **Action:** call orchestrator with `event_type = "alert", trigger_reason = "unsafe_zone"`. The orchestrator:
  1. Sends real Twilio/WhatsApp SOS (per FR-4, API_SPEC.md §5).
  2. Pushes SSE event `trip_update` with `event_type: "alert"` to the client.
- **Demo fireable endpoint:** `POST /trips/{trip_id}/simulate-safety-trigger` (API_SPEC.md §5).

### 3.3 Budget Watcher
- **Input:** running spend (accumulated from legs already completed + current leg's cost), `max_budget_inr`.
- **Poll logic:** every time a leg is completed (or every N seconds), add the leg's `cost_inr` to the running total.
- **Trigger condition:** if the next leg's `cost_inr` would cause `running_spend + next_leg_cost > max_budget_inr`.
- **Action:** call orchestrator with `event_type = "budget_violation", suggested_mode = "cheaper_alternative"`. The orchestrator re-plans with a cheaper mode substitution for the offending leg.
- **UI effect:** Reroute Toast (Screen 4) with copy like "Auto selected — switched to auto for this leg to stay under budget."

---

## 4. Amenity Search (RAG-Lite)

Given a destination coordinates, search the curated amenities table (DATABASE.md §3) for budget stay and food options within ~2 km.

- If the curated dataset has no embedded embeddings, a simple **radius PostGIS query** `ST_DWithin(amenity_geom, point, 2)` is used.
- Results are sorted by distance, limited to 3-5 items per category.
- No vector search is required for demo scope — the curated dataset is small enough for exact-radius search.

---

*Next doc: `DATABASE.md` — the Postgres schema, curated datasets, and spatial queries.*