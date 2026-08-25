## API_SPEC.md — Backend Endpoints and Contracts

> **Purpose of this doc:** the concrete REST/SSE contract between frontend and backend. Every endpoint here maps to a flow described in ARCHITECTURE.md §3/§4 and reads/writes the tables in DATABASE.md — if you add an endpoint, trace it back to both before merging.

---

**Base URL (dev):** `http://localhost:8000/api/v1` on a machine; from the **Android emulator**, use `http://10.0.2.2:8000/api/v1` instead (`localhost` inside the emulator refers to the emulator itself, not your dev machine) — the **iOS Simulator**, by contrast, can reach `localhost` directly. Handle this per-platform difference via the build-time `API_BASE_URL` config (ARCHITECTURE.md §6), not a runtime `Platform.isAndroid` check buried in a repository class.

**Auth (demo scope):** none required — a `user_id` is generated client-side on first app launch (stored via `flutter_secure_storage`, not `shared_preferences`) and sent as a header (`X-User-Id`). Production auth model is out of scope for hackathon (flagged in SECURITY.md §2).

**Client implementation note (Flutter):** this is a REST + Server-Sent-Events API, consumed from Dart via `dio` (REST endpoints) and a Dio streamed response (or the `flutter_client_sse` package) for the SSE endpoint (§3) — Flutter has no built-in `EventSource` (that's a browser API). Do not attempt to add a JS/web client to this repo; see AGENTS.md §0.

---

## 1. `POST /trips` — Create a trip from natural language

**Request:**
```json
{
  "query": "Howrah to Salt Lake Sector V, budget 200, need to reach by 10am",
  "emergency_contact_phone": "+919800000000"
}
```

**Response `201`:**
```json
{
  "trip_id": "uuid",
  "status": "active",
  "parsed_intent": {
    "origin": "Howrah Railway Station",
    "destination": "Salt Lake Sector V",
    "max_budget_inr": 200,
    "target_eta": "2026-08-25T10:00:00+05:30"
  },
  "itinerary": {
    "total_cost_inr": 160,
    "total_time_minutes": 55,
    "legs": [
      {
        "leg_index": 1,
        "mode": "train",
        "from": "Howrah Junction",
        "to": "Sealdah Station",
        "scheduled_departure": "2026-08-25T08:15:00+05:30",
        "cost_inr": 10
      }
    ]
  },
  "amenities": {
    "budget_food": [{"name": "Express Meal Center", "price_inr": 70, "distance_km": 0.3}],
    "budget_stay": [{"name": "Urban Travel Hostel", "price_inr": 4800, "distance_km": 0.6}]
  }
}
```

**Error cases:**
- `422` — intent parser couldn't extract a required field (budget or destination); response includes `clarification_needed` with the specific missing field, per PRD.md FR-1 ("ask at most one clarifying question").
- `409` — no candidate itinerary exists under the stated budget; response includes the cheapest available option's cost so the client can show "not possible under ₹X, cheapest is ₹Y."

---

## 2. `GET /trips/{trip_id}` — Fetch current trip + active itinerary

Returns the same shape as the `POST /trips` response body, reflecting current DB state (i.e. post-replan state if any triggers have already fired).

---

## 3. `GET /trips/{trip_id}/events` — Server-Sent Events stream

Long-lived connection the client opens right after trip creation (ARCHITECTURE.md §3 step 7). Each event corresponds to a `trip_events` row (DATABASE.md §2) at the moment it's inserted.

**Event payload shape:**
```
event: trip_update
data: {
  "event_type": "replan",
  "trigger_reason": "delay",
  "old_leg": { "leg_index": 2, "mode": "bus" },
  "new_leg": { "leg_index": 2, "mode": "auto", "cost_inr": 45 },
  "message": "Bus delayed 18 min — switched to auto for this leg."
}
```
```
event: trip_update
data: {
  "event_type": "alert",
  "trigger_reason": "unsafe_zone",
  "message": "Entered a flagged zone — emergency contact notified.",
  "twilio_sid": "SMxxxxxxxx"
}
```

Client renders each event as a toast + map update; it never needs to poll.

---

## 4. `POST /trips/{trip_id}/simulate-delay` — Demo-only trigger

**This endpoint exists specifically for the live hackathon demo** (PRD.md §7) — since there's no live transit feed, this lets a presenter fire a real delay event on cue instead of waiting for/faking a background poll.

**Request:**
```json
{ "leg_index": 2, "delay_minutes": 18 }
```
**Response `202`:** `{ "accepted": true }` — the actual replan result arrives over the SSE stream (§3), not in this response, to keep the demo showing the *real* async agent flow, not a synchronous shortcut.

---

## 5. `POST /trips/{trip_id}/simulate-safety-trigger` — Demo-only trigger

Same purpose as §4, for the safety watcher path.

**Request:**
```json
{ "zone_id": "uuid-of-a-seeded-safety-zone" }
```
**Response `202`:** `{ "accepted": true }` — real Twilio call fires, real SSE event follows, per PRD.md §7 ("Twilio call must stay real").

---

## 6. `GET /amenities` — Standalone amenity search (used outside an active trip too)

**Query params:** `lat`, `lng`, `radius_km` (default 2), `query` (free text, optional — triggers the RAG path in AI_PIPELINE.md §4), `category` (`budget_food` | `budget_stay`, optional).

**Response `200`:**
```json
{
  "results": [
    { "name": "Express Meal Center", "category": "budget_food", "price_inr": 70, "distance_km": 0.3, "description": "..." }
  ]
}
```

---

## 7. `POST /emergency-contacts` — Register/update emergency contact

**Request:** `{ "phone_number": "+919800000000", "relation": "parent" }`
**Response `201`:** the created row. Phone number is validated as E.164 at this boundary — see SECURITY.md §3 for why this validation matters beyond just data quality.

---

## 8. Error Response Shape (applies to all endpoints)

```json
{
  "error": {
    "code": "BUDGET_INFEASIBLE",
    "message": "No itinerary found under ₹150. Cheapest available is ₹210.",
    "details": {}
  }
}
```

Error `code` values are a fixed enum shared between frontend and backend (kept in a shared constants file, not re-typed independently on both sides — avoids the two drifting apart).

---

*Next doc: `UI_SPEC.md` — how the frontend renders each of these responses/events, screen by screen.*