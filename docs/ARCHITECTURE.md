## ARCHITECTURE.md — How Frontend / Backend / AI / Database Connect

> **Purpose of this doc:** the single reference for how Raahi's pieces fit together end-to-end. If AI_PIPELINE.md, DATABASE.md, or API_SPEC.md ever disagree with this file on a boundary/contract, this file is the tiebreaker — fix the drift, don't just pick one.

---

## 1. System Overview

**Platform note:** the client is a **cross-platform mobile app built with Flutter (Dart)**, developed from Android Studio with the Flutter/Dart plugins — not a web app, and not a native-Kotlin/Swift app. See AGENTS.md §0 for the explicit stack boundary this implies for anyone (human or AI agent) working on this repo.

Raahi is a **4-layer system**: Client → API/Orchestration → Agent Layer → Data/External Services. Each layer has one job and talks to its neighbor through a defined contract, never reaching across a layer. The Flutter client is just an HTTP/SSE consumer of the backend — none of the three layers below it change based on what client is talking to them, which is exactly why this architecture was already client-agnostic before Flutter was chosen.

```
┌─────────────────────────────────────────────────────────┐
│ CLIENT LAYER                                             │
│ Flutter app (Dart) — Android + iOS from one codebase      │
│ mapbox_maps_flutter — UI, live map, itinerary display     │
└──────────────────────────┬────────────────────────────────┘
                            │ REST (JSON) + SSE (live updates)
┌──────────────────────────▼────────────────────────────────┐
│ API & ORCHESTRATION LAYER                                 │
│ FastAPI (request handling, auth) + LangGraph (agent loop)  │
└──────────────────────────┬────────────────────────────────┘
                            │ function calls / internal events
┌──────────────────────────▼────────────────────────────────┐
│ AGENT LAYER                                                │
│ Planning agents (intent parser, route planner)             │
│ Monitoring agents (delay / safety / budget watchers)        │
└──────────────────────────┬────────────────────────────────┘
                            │ queries / API calls
┌──────────────────────────▼────────────────────────────────┐
│ DATA & EXTERNAL SERVICES LAYER                              │
│ PostgreSQL+PostGIS · curated transit dataset · Groq/Gemini  │
│ · Twilio/WhatsApp · Rapido/Uber deep-links                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Why This Layering (rationale, not just diagram)

- **Client never talks to the agent layer directly.** Every request goes through FastAPI so we have one place to enforce auth, rate limits, and request validation — the agent layer trusts its caller completely, which is only safe because FastAPI is the only caller.
- **LangGraph owns agent sequencing, not FastAPI route handlers.** A route handler's job is "receive request → hand to orchestrator → return result." If agent-sequencing logic leaks into route handlers, the monitor loop becomes impossible to reason about (see AI_PIPELINE.md §3 for the loop's own internal structure).
- **The monitoring agents never call the LLM directly for routine polls.** Only re-planning (after a trigger fires) invokes the LLM/utility-scoring path again. Routine watcher polls are cheap deterministic checks (threshold comparisons), not LLM calls — this keeps the system fast and within free-tier limits.

---

## 3. Request Flow — Trip Creation (happy path)

1. Client sends `POST /api/v1/trips` with raw text query.
2. FastAPI validates the request shape, forwards to the orchestrator.
3. **Intent Parser Agent** (LLM call) converts text → structured JSON (`origin`, `destination`, `max_budget_inr`, `target_eta`).
4. Orchestrator hands structured JSON to **Route Planner Agent**.
5. Route Planner queries PostGIS (spatial + safety-zone data) and the curated transit dataset, generates candidate itineraries, scores them via the utility function (AI_PIPELINE.md §2), returns the best one.
6. FastAPI persists the trip + itinerary in Postgres, returns the itinerary JSON to the client.
7. Client renders the itinerary on Mapbox and **opens an SSE connection** for live trip events.
8. Orchestrator starts the **monitor loop** for this trip (delay/safety/budget watchers), which now runs independently of the original request/response cycle.

---

## 4. Request Flow — Live Trigger (delay example)

1. Delay watcher's poll (simulated event source in demo) detects a delay exceeding threshold for the active leg.
2. Watcher calls back into the orchestrator: "replan needed, reason=delay, leg_id=X."
3. Orchestrator re-invokes the Route Planner Agent with the current position as the new origin and the same budget/ETA constraints.
4. New itinerary persisted, diffed against the old one.
5. Diff pushed to the client over the open SSE connection — client updates the map without a full page reload or a new user request.

This same shape (watcher → orchestrator → replan/act → SSE push) is reused for the safety trigger (→ Twilio alert instead of replan) and the budget trigger (→ mode substitution).

---

## 5. Why No Live Transit API (architectural consequence, not just a data note)

This is an architectural decision, not just a data-scope note in PRD.md — it shapes the Data layer directly:

- No GTFS ingestion pipeline exists in this architecture. The "Transit Dataset" box in §1 is a **static, curated table** (see DATABASE.md §3), not a live feed consumer.
- The Delay Watcher's "poll" step is therefore a poll against a **simulated event table** we control (for demo reliability), not a scheduled job hitting an external API. This keeps the demo deterministic and repeatable — the same delay can be triggered on cue during judging.
- Post-hackathon, the only architectural change needed to support live data is swapping the Data layer's transit source — the Agent layer and API contracts do not need to change. This is the payoff of keeping layers strictly separated.

---

## 6. Deployment Shape (hackathon scope)

```
docker-compose:
  ├── postgres (with PostGIS extension)
  └── backend (FastAPI + LangGraph, single container)
```

The Flutter app is **not part of docker-compose** — it's built and run separately via Android Studio (Flutter plugin) or `flutter run` from the integrated terminal, and points at the backend's base URL via `--dart-define=API_BASE_URL=...` (or a `.env` read by `flutter_dotenv`), so debug vs release builds can point at different backends without a code change.

- Single-region, single-instance deployment is sufficient for demo purposes — no need for horizontal scaling, queues, or multi-region failover in v1.
- Twilio and the LLM provider are the only external network dependencies at runtime; everything else (transit data, safety zones, amenities) is local to Postgres.
- **Emulator/simulator networking note:** the Android emulator reaches a locally-run backend at `10.0.2.2`, while the iOS Simulator reaches it directly at `localhost` — this difference must be handled by the build-time `API_BASE_URL` config (per-platform), not hardcoded in Dart source.

---

## 7. Tech Stack Summary (with rationale)

| Layer | Tool | Why this, not an alternative |
|---|---|---|
| Client | Flutter (Dart) | One codebase for Android (hackathon demo target) and iOS; avoids maintaining two native clients under hackathon time pressure |
| Client state/DI | Riverpod | Provider-based state + dependency injection in one mechanism, testable without a running app |
| Maps | `mapbox_maps_flutter` | Official Flutter plugin — same custom-layer control (safety-zone overlays) as the web/native Mapbox SDKs, via a Dart API |
| Client networking | Dio | Standard, well-supported Flutter REST client with interceptor support (for the `X-User-Id` header); its streamed responses also back the SSE client (see AGENTS.md §4) |
| Client local cache | Hive | Lightweight local persistence for the active trip only, for offline resilience — not a general-purpose client database |
| Backend API | FastAPI (Python) | Async-native, Pydantic validation lines up with our structured-JSON-everywhere approach |
| Orchestration | LangGraph | Explicit graph/state model fits a multi-agent loop better than ad-hoc chained LLM calls |
| LLM | Groq (Llama 3.1) primary, Gemini 1.5 Flash fallback | Groq's inference speed matters for the <3s itinerary target; Gemini fallback covers Groq outages |
| Spatial DB | PostgreSQL + PostGIS | Native geospatial queries (radius search, zone containment) without a separate geo-service |
| Alerts | Twilio / WhatsApp Business API | Only viable free/low-cost path to a real SMS/WhatsApp SOS for the demo |
| Routing algorithm | Custom weighted Dijkstra/A* | Off-the-shelf routing engines (OpenTripPlanner) require GTFS we don't have — custom graph over our curated dataset is simpler and fully controllable |

---

*Next doc: `AI_PIPELINE.md` — the internals of the intent parser, utility scoring, and the RAG/embedding layer (if used for amenity search).*