## AGENTS.md — How OpenCode Should Work on This Repo

> **Purpose of this doc:** operating instructions for any AI coding agent (OpenCode, Claude Code, etc.) working inside the Raahi repo. Read this before writing or modifying any file. If something here conflicts with a request in chat, this file wins unless the human explicitly overrides it in that session.

---

## 0. Platform Declaration — READ THIS FIRST

**This is a cross-platform mobile app built with Flutter (Dart), developed and run from Android Studio (with the Flutter/Dart plugins installed).** This is not a web app, not a Next.js project, and there is no browser-based frontend anywhere in this repo. It is also **not a native-Android-views (Kotlin/Jetpack Compose) project** — the entire UI is Flutter widgets, in Dart.

**The agent must NEVER generate, suggest, or scaffold any of the following, under any circumstances:**
- `.ts` / `.tsx` files, React, Next.js, Vite, or any Node.js-based frontend
- Prisma, or any Node/JS ORM
- `package.json` at the project root implying a JS frontend build
- Browser-only APIs (`localStorage`, `EventSource`, DOM APIs, `fetch` in a browser context)
- Native Android UI code — no Kotlin `@Composable` functions, no XML layouts, no Jetpack Compose, no Activities/Fragments as UI containers. The `android/` folder that Flutter generates is build-configuration only (Gradle, manifest, signing) — **application UI and logic never go there.**
- Native iOS UI code (SwiftUI/UIKit) — same reasoning, the `ios/` folder is build-configuration only.
- Mapbox **GL JS** (the web SDK) — this project uses the **`mapbox_maps_flutter`** plugin, a completely different API surface from both the web SDK and the native Android/iOS SDKs.

**The client is Flutter + Dart, full stop.** If the agent is about to write a `.ts` file, a `.tsx` file, a `schema.prisma` file, or a Kotlin `.kt` UI file, it has misread the task — stop and re-read this section and §2 below before continuing.

**Why this note exists:** the original architecture docs for this project were drafted stack-agnostic (and briefly, incorrectly, assumed native Android/Kotlin before the Flutter decision was finalized) using generic web terms an agent can default to as React. Every doc in this repo (ARCHITECTURE.md, UI_SPEC.md, API_SPEC.md) has since been corrected to Flutter-specific terminology — if you (the agent) see a stray web-stack or native-Android reference anywhere in a doc that contradicts this section, **this section wins.**

The backend (FastAPI, Python — see ARCHITECTURE.md) is unaffected by this note and continues to live in its own service, consumed by the Flutter app over REST/SSE like any other client would.

---

## 1. Read Order Before Touching Code

1. `PRD.md` — what we're building, what's in/out of scope
2. `ARCHITECTURE.md` — how the pieces connect
3. The specific spec file for whatever you're touching (`AI_PIPELINE.md`, `DATABASE.md`, `API_SPEC.md`, `UI_SPEC.md`, `SECURITY.md`)

Never start writing a feature by inferring scope from the codebase alone — the PRD is the source of truth, not existing code (existing code may be a stale hackathon shortcut).

---

## 2. Repository Structure (target layout)

```
raahi/
├── PRD.md
├── AGENTS.md
├── ARCHITECTURE.md
├── AI_PIPELINE.md
├── DATABASE.md
├── API_SPEC.md
├── UI_SPEC.md
├── SECURITY.md
├── backend/                            # Python FastAPI service — separate from the Flutter app
│   ├── app/
│   │   ├── main.py                     # FastAPI entrypoint
│   │   ├── agents/
│   │   │   ├── intent_parser.py        # NL -> structured JSON
│   │   │   ├── route_planner.py        # utility scoring + candidate generation
│   │   │   ├── monitor_loop.py         # delay/safety/budget watchers
│   │   │   └── orchestrator.py         # LangGraph graph definition
│   │   ├── routers/                    # FastAPI route modules, one per resource
│   │   ├── models/                     # Pydantic schemas (request/response)
│   │   ├── db/                         # SQLAlchemy models + PostGIS queries
│   │   ├── services/
│   │   │   ├── twilio_client.py
│   │   │   ├── llm_client.py           # Groq/Gemini wrapper with fallback
│   │   │   └── deep_links.py           # Rapido/Uber URL builders
│   │   └── data/                       # curated static datasets (transit, safety zones, amenities)
│   ├── tests/
│   └── requirements.txt
├── mobile/                              # FLUTTER APP — this is the entire client
│   ├── pubspec.yaml
│   ├── analysis_options.yaml            # flutter_lints / very_good_analysis rules
│   ├── android/                         # build config ONLY (Gradle, manifest, signing) — no UI code here
│   ├── ios/                             # build config ONLY (Info.plist, signing) — no UI code here
│   └── lib/
│       ├── main.dart
│       ├── app.dart                     # MaterialApp + go_router setup
│       ├── data/
│       │   ├── remote/
│       │   │   ├── raahi_api_client.dart    # Dio-based REST client, mirrors API_SPEC.md
│       │   │   ├── sse_client.dart          # live trip-events stream (Stream<TripEvent>)
│       │   │   └── dto/                     # request/response models (freezed + json_serializable)
│       │   └── local/
│       │   │   └── trip_cache.dart          # Hive box — local cache of the active trip only
│       ├── domain/
│       │   └── models/                      # plain Dart domain models (Trip, Leg, TripEvent…)
│       ├── features/
│       │   ├── trip_request/                # Screen 1 — widget + Riverpod provider(s)
│       │   ├── active_trip/                 # Screen 3 — widget + Riverpod provider(s)
│       │   ├── safety_alert/                # Screen 5 — widget + Riverpod provider(s)
│       │   ├── amenities/                   # Screen 6 — widget + Riverpod provider(s)
│       │   └── settings/                    # Screen 9 — widget + Riverpod provider(s)
│       ├── shared/
│       │   ├── widgets/                     # shared widgets (leg card, toast, map overlay)
│       │   └── theme/                       # Material3 theme, color tokens
│       └── routing/
│           └── app_router.dart              # go_router route definitions
│   ├── test/                            # unit + widget tests
│   └── integration_test/                # end-to-end tests
└── infra/
    └── docker-compose.yml               # postgres+postgis + backend only — the Flutter app is not containerized
```

**Critical distinction from a typical web project:** there is no `frontend/` directory and no root-level `package.json`. The Flutter app is a **single Dart codebase** rooted at `mobile/`, opened as a Flutter project (Android Studio's Flutter plugin recognizes `pubspec.yaml` as the project root). The `android/` and `ios/` subfolders inside `mobile/` are Flutter-generated platform shells for building/signing — the agent should essentially never need to write application code inside them.

If you need to deviate from this structure, update this file in the same commit — don't let the doc drift from reality.

---

## 3. Ground Rules for the Agent

- **Never invent live API integrations** that PRD.md §7 explicitly excludes (IRCTC, live GTFS, live crowdsourced safety data). If a task seems to require one, stop and flag it instead of mocking a fake "live" call that silently does nothing.
- **The Twilio/WhatsApp call must stay real**, even in local dev — use a Twilio test/trial credential, never fully mock this path, since it's the core demo differentiator (see SECURITY.md for credential handling).
- **Every LLM call must have a fallback provider.** If Groq is primary, Gemini must be the fallback (or vice versa, per PRD.md open decision) — no unhandled provider outage should break trip planning.
- **Budget ceiling is a hard constraint**, not a soft preference — never let route-generation code silently return a route above the user's stated ceiling.
- **Don't add new Python/Node dependencies** without checking they have a free tier / no paid license requirement, per PRD.md §9.

---

## 4. Coding Conventions

**Backend (Python / FastAPI):**
- Format with `black`, lint with `ruff`.
- All request/response bodies are Pydantic models — no raw dicts crossing a route boundary.
- Async everywhere I/O is involved (DB, LLM calls, Twilio) — no blocking calls in route handlers.
- One agent = one file under `app/agents/`. Don't merge agent logic into route handlers.

**Flutter client (Dart):**
- **Architecture:** feature-first, with Riverpod as both state management and dependency injection. Each screen = one widget (`ConsumerWidget`/`ConsumerStatefulWidget`) + one or more Riverpod providers (`AsyncNotifierProvider` for anything backend-driven). Widgets are as stateless as possible — they watch provider state and call provider methods, they never call the repository or `Dio` client directly.
- **DI:** Riverpod providers are the dependency-injection mechanism (`raahiApiClientProvider`, `tripRepositoryProvider`, etc.) — no service locator pattern, no manually instantiated singletons scattered across widgets.
- **Networking:** `dio` for REST calls (`raahi_api_client.dart`, mirroring API_SPEC.md's endpoints exactly — one method per endpoint), with `json_serializable` + `freezed` for the DTOs in `data/remote/dto/`.
- **Live events:** the `GET /trips/{id}/events` SSE stream (API_SPEC.md §3) has no built-in Dart/Flutter equivalent to the browser's `EventSource` — implement `sse_client.dart` using Dio's streamed `ResponseType.stream` (or the `flutter_client_sse` package) to parse the `event:`/`data:` lines manually, exposed to the UI layer as a `Stream<TripEvent>`, not a callback.
- **Async:** Dart's native `Future`/`Stream` + Riverpod's `AsyncValue` for representing loading/data/error — no raw callback-based async left unwrapped in the UI layer.
- **Maps:** the official `mapbox_maps_flutter` plugin. This is a different API from both Mapbox GL JS and the native Android/iOS Mapbox SDKs — do not port code patterns from either.
- **Local storage:** `hive` (or `drift` if a relational local cache is preferred), and only for caching the currently active trip for offline resilience (per DATABASE.md's client-cache note) — it is not a replacement for the backend Postgres database and must never accumulate historical trips indefinitely.
- **Secure storage:** `flutter_secure_storage` for the client-generated `user_id` (backed by Android Keystore / iOS Keychain under the hood) — never plain `SharedPreferences`/`shared_preferences` package for anything identity-related.
- **Navigation:** `go_router` for all screen navigation — no raw `Navigator.push` with ad-hoc routes scattered through the codebase.
- **Lint/format:** `flutter_lints` (or `very_good_analysis` for a stricter ruleset) + `dart format`, enforced via `analysis_options.yaml`.
- **Widget tests** required for every new screen-level widget (`test/features/.../..._test.dart`), so UI logic can be verified without running the full app on a device/emulator.

**Commits:**
- Conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).
- One logical change per commit — don't bundle a new agent + a UI change + a schema migration into one commit.

---

## 5. Testing Expectations

- Every new agent function (`intent_parser`, `route_planner`, watchers) needs at least one unit test with a fixed input/output pair — LLM calls should be mocked in unit tests, not hit live in CI.
- The utility scoring function (`route_planner.score()`) must have tests covering: budget-violating candidate rejected, safety-weighted candidate wins over faster-but-unsafe candidate.
- Integration test for the full monitor loop trigger chain is encouraged but not blocking for hackathon velocity — flag as `# TODO: integration test` if skipped under time pressure, don't skip silently.

---

## 6. Environment & Secrets

- All secrets (Groq/Gemini API keys, Twilio credentials, DB connection string) live in `.env`, never hardcoded, never committed. `.env.example` must be kept up to date whenever a new secret is introduced.
- See `SECURITY.md` for the full credential-handling policy before touching anything auth-related.

---

## 7. When the Agent Is Unsure

If a task is ambiguous relative to PRD.md scope (e.g. "should this route also handle flights?" — it shouldn't, per PRD §4 non-goals), the agent should:
1. State the ambiguity explicitly
2. State the PRD section that seems to resolve it
3. Proceed with the PRD-consistent interpretation, or ask if the PRD section itself needs updating

Do not silently expand scope to "be more helpful" — scope creep is the #1 risk for a hackathon timeline.

---

*Next doc: `ARCHITECTURE.md` — defines how frontend, backend, AI / database connect end-to-end.*