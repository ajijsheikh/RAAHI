# 🧭 Raahi — Agentic Safety-Aware Travel Companion

> An AI agent that doesn't just plan your trip — it stays with you through it.

Raahi turns a plain-language trip request into a complete, budget-constrained, multi-leg itinerary — and then stays **autonomously active** for the duration of the trip: rerouting on delay, alerting emergency contacts on entering an unsafe zone, and switching modes if a leg goes over budget. No manual re-planning. No separate apps for maps, rideshare, and safety.

Built for **[Hackathon Name] 2026** · Domain: **Travel & Tourism**

---

## 🚩 The Problem

A solo traveler, student, or newcomer arriving in an unfamiliar city today juggles 4+ apps — maps, rideshare, accommodation search, and no real-time safety net — and has to manually notice and fix every problem along the way (a delayed bus, an unsafe area, a budget overrun).

**91% of women in India report feeling public transport is unsafe** ([Springer, 2025](https://link.springer.com/chapter/10.1007/978-3-031-88974-5_76)), and NCW's 2025 NARI survey ranked Kolkata among the least safe cities by lived experience. No existing travel tool treats safety as a routing factor — it's always an afterthought, if present at all.

## 💡 The Solution

Raahi is a genuinely **agentic** system — not a chatbot wrapper. Three autonomous watchers run continuously once a trip is active:

| Watcher | Trigger | Autonomous Action |
|---|---|---|
| 🕐 **Delay Watcher** | Delay threatens next connection/ETA | Silently replans and updates the itinerary |
| 🛡️ **Safety Watcher** | Entry into a flagged unsafe zone | Sends a real SMS/WhatsApp SOS to emergency contact, with live location |
| 💰 **Budget Watcher** | Running cost nears the budget ceiling | Switches to a cheaper mode automatically |

No button presses. No user action required between trigger and response — that's the entire point.

---

## ✨ Key Features

- **Natural language trip planning** — "Howrah se Salt Lake Sector V, ₹200, 10 baje tak" → full itinerary, Hinglish included
- **Multi-objective route scoring** — weighs cost, time, transfers, and a *minimum-across-legs* safety score; hard-rejects anything over budget
- **Route presets** — Fastest / Cheapest / Safest chips that visibly change the recommended itinerary
- **Live autonomous rerouting** — no user input between a delay and the updated plan
- **Real emergency alerts** — actual Twilio SMS/WhatsApp to a registered contact, not a simulated toast
- **Budget-and-safety-aware amenities** — verified stay/food suggestions filtered by *remaining* budget and walk-path safety, not just proximity
- **Cab handoff** — one-tap deep links to Uber/Ola/Rapido with pickup/drop pre-filled (no in-app payments by design)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│  CLIENT — Flutter (Dart)                     │
│  Riverpod · go_router · mapbox_maps_flutter  │
└───────────────────┬───────────────────────────┘
                     │ REST + Realtime (Supabase) / SSE
┌───────────────────▼───────────────────────────┐
│  BACKEND — FastAPI (Python)                   │
│  LangGraph orchestration                      │
├─────────────────────────────────────────────────┤
│  AGENTS                                        │
│  • Intent Parser   (Groq / Gemini — NL→JSON)  │
│  • Route Planner   (weighted graph search)     │
│  • Monitor Loop    (delay/safety/budget)       │
│  • Amenity Agent    (budget+safety scoring)    │
└───────────────────┬───────────────────────────┘
                     │
┌───────────────────▼───────────────────────────┐
│  DATA — PostgreSQL + PostGIS (Supabase)        │
│  Curated transit routes · safety zones ·       │
│  amenities · trip events (audit log)           │
├─────────────────────────────────────────────────┤
│  EXTERNAL — Twilio (SOS) · Rapido/Uber/Ola     │
│  deep-links · Mapbox                           │
└─────────────────────────────────────────────────┘
```

Full docs: [`ARCHITECTURE.md`](./docs/ARCHITECTURE.md) · [`AI_PIPELINE.md`](./docs/AI_PIPELINE.md) · [`API_SPEC.md`](./docs/API_SPEC.md)

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Mobile client | Flutter (Dart), Riverpod, go_router, `mapbox_maps_flutter` |
| Backend | FastAPI (Python 3.11), LangGraph |
| LLM | Groq (Llama 3.1) primary, Gemini 1.5 Flash fallback |
| Database | PostgreSQL + PostGIS (via Supabase) |
| Auth & Realtime | Supabase Auth, Supabase Realtime |
| Alerts | Twilio (SMS/WhatsApp) |
| Routing algorithm | Custom weighted Dijkstra/A* with multi-objective scoring |

---

## 🚀 Getting Started

### Prerequisites

- Python 3.11
- Flutter SDK (latest stable)
- A [Supabase](https://supabase.com) project (free tier)
- API keys: [Groq](https://console.groq.com), [Gemini](https://aistudio.google.com/apikey), [Twilio](https://twilio.com/try-twilio) (trial), [Mapbox](https://mapbox.com)

### Backend Setup

```bash
cd backend
python3.11 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env        # then fill in your keys
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

`.env` required variables:
```
GROQ_API_KEY=
GEMINI_API_KEY=
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM_NUMBER=
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_JWT_SECRET=
DATABASE_URL=
```

Verify it's running:
```bash
curl http://localhost:8000/health
```

### Mobile App Setup

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
            --dart-define=SUPABASE_URL=your_supabase_url \
            --dart-define=SUPABASE_ANON_KEY=your_anon_key \
            --dart-define=MAPBOX_ACCESS_TOKEN=your_mapbox_token
```

> Android emulator reaches your local backend at `10.0.2.2`. iOS Simulator uses `localhost` directly.

### Database Setup

Schema, seed data, and PostGIS/RLS setup: see [`docs/DATABASE.md`](./docs/DATABASE.md).

---

## 📂 Project Structure

```
raahi/
├── AGENTS.md              # Instructions for AI coding agents (OpenCode/Claude Code)
├── docs/                  # Full technical documentation
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── AI_PIPELINE.md
│   ├── DATABASE.md
│   ├── API_SPEC.md
│   ├── UI_SPEC.md
│   └── SECURITY.md
├── backend/                # FastAPI service
│   └── app/
│       ├── agents/          # intent_parser, route_planner, monitor_loop, amenity_agent
│       ├── routers/
│       ├── services/        # twilio_client, llm_client, deep_links
│       └── data/            # curated seed datasets
└── mobile/                 # Flutter client
    └── lib/
        ├── features/        # one folder per screen
        ├── data/
        └── domain/
```

---

## 🎥 Demo

*(add demo video link / GIF here)*

**What to look for:** type a trip request, then trigger a simulated delay — watch the itinerary update **without touching anything**. Then trigger a simulated unsafe-zone entry — a real SMS lands on a real phone.

---

## ⚠️ Known Scope Decisions

We deliberately excluded a few things — documented, not hidden:

- **No live IRCTC/GTFS integration** — no reliable open transit API exists for most Indian cities. We use a curated static dataset for the demo city, with the architecture designed so swapping in live data later is a data-layer change, not a rearchitecture.
- **No in-app payments/booking** — we hand off to Uber/Ola/Rapido via deep-links instead, since no free-tier programmatic booking API exists for the Indian market.
- **Safety-zone data is manually seeded for the demo**, clearly labeled by source — never presented with false authority as verified/official data.

Full reasoning in [`docs/PRD.md`](./docs/PRD.md) §7.

---

## 👥 Team

| Name | Role |
|---|---|
| [Name] | Backend + AI Agents |
| [Name] | Flutter Client |
| [Name] | Data, Infra, Auth, Alerts |

---

## 📄 License

*(add your license here — MIT is a common choice for hackathon projects)*
