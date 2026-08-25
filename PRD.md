# PRD.md — Raahi: Agentic Safety-Aware Travel Companion

## 1. Product Summary

**One-liner:** Raahi is an autonomous AI agent that plans a solo traveler's entire trip — route, budget stay, and food — and stays active through the journey to reroute on delay, flag unsafe zones, and auto-alert emergency contacts, without the user re-prompting it.

**Category:** Travel & Tourism (with a safety-critical differentiator).

**Not this:** Raahi is not a general-purpose maps app, not a booking/payment platform, and not a dedicated women-safety-only app. It is a trip-execution agent for people navigating an unfamiliar city alone.

---

## 2. Problem Statement

A solo traveler, student, or newcomer arriving in an unfamiliar Indian city today has to:

1. Open Google Maps for directions
2. Open a rideshare app for last-mile transport
3. Open a separate app (or ask around) for budget stay/food
4. Manually re-plan everything the moment a bus is late or a train is delayed
5. Have no real-time safety net if they enter an unfamiliar or unsafe area

No single tool unifies these, and **none of them act autonomously** — they all require the user to notice a problem and manually fix it.

---

## 3. Target Users

| Persona | Context | Primary need |
|---|---|---|
| **Relocating student** | New to a city for college, no local knowledge | Cheap, safe route from station to hostel/PG |
| **Solo budget traveler** | Visiting a new city, tight budget | Multimodal route + verified cheap stay/food |
| **Newcomer worker** | Relocating for a job | Safe last-mile navigation, unfamiliar area alerts |

**Explicitly not targeted (v1):** group travel, corporate travel management, long-term city residents.

---

## 4. Goals

### Product goals
- G1: Turn a plain-language trip request into a complete, budget-constrained, multi-leg itinerary in under 3 seconds.
- G2: Keep the itinerary alive and self-correcting for the duration of the trip (no manual re-planning on delay).
- G3: Detect unsafe-zone entry and notify emergency contacts without requiring the user to act.
- G4: Recommend verified budget stay/food near the destination as part of the same flow.

### Hackathon demo goals (scoped separately — see §7)
- Reliable, judge-facing demo with zero dependency on unstable third-party live APIs.
- Visibly demonstrate *autonomous* behavior (delay → reroute, geofence → alert) without user input during the trigger.

### Non-goals (v1)
- No in-app payments or ticket booking.
- No web/desktop client — the app is a Flutter mobile app (Android primary target for the hackathon demo; iOS buildable from the same codebase but not the demo focus).
- No live GTFS/IRCTC integration (data reliability issue — see ARCHITECTURE.md §5).
- No multi-user/group trip coordination.

---

## 5. Core User Stories

1. **As a newcomer**, I type "Howrah to Salt Lake Sector V, ₹200, need to arrive by 10 AM" and get a full route with cost breakdown, so I don't have to compare apps manually.
2. **As a solo traveler**, if my bus is delayed past a threshold, I want the app to silently recompute my route and notify me of the change, so I don't miss my ETA without knowing why.
3. **As a traveler entering an unfamiliar area**, I want the app to detect if I've entered a flagged zone and alert my emergency contact automatically, so help can be triggered even if I can't act myself.
4. **As a budget-conscious user**, I want nearby verified PG/hostel and food options within my cost ceiling shown alongside my route, so I don't need a separate app for that.
5. **As a user whose planned mode becomes too expensive mid-trip** (e.g. surge pricing), I want the agent to switch to a cheaper mode automatically and tell me it did, so my budget ceiling is never silently violated.

---

## 6. Functional Requirements

### FR-1 — Natural language trip intake
- Input: free text (and optionally voice-to-text) describing origin, destination, budget ceiling, target ETA, and optionally an emergency contact.
- Output: structured JSON (`origin`, `destination`, `max_budget_inr`, `target_eta`, `emergency_contact`, `amenities_requested[]`).
- Must handle incomplete input gracefully — ask at most one clarifying question, don't fail silently.

### FR-2 — Multi-leg itinerary generation
- Combine available modes (walk, bus, metro, train, auto/rickshaw, rideshare deep-link) into an ordered itinerary.
- Rank candidates via the utility scoring function (see AI_PIPELINE.md §2).
- Must respect the user's hard budget ceiling — never return a route that exceeds it, unless no route exists under budget, in which case say so explicitly.

### FR-3 — Continuous trip monitoring (the "agentic" core)
Three watchers run for the duration of an active trip:
- **Delay watcher:** polls (simulated in demo) transit status; if delay > threshold and it endangers the next connection, triggers a reroute automatically.
- **Safety watcher:** checks current location against flagged-zone data; on entry, triggers an alert.
- **Budget watcher:** tracks running spend; if a leg would exceed the ceiling, triggers a cheaper-mode substitution.

### FR-4 — Emergency alert
- On safety trigger, send an SOS (via Twilio/WhatsApp) to the user's pre-registered emergency contact with live coordinates and a map link.
- No manual button required for this path (though a manual "I need help" button also exists as a fallback).

### FR-5 — Amenity discovery
- Given the destination, return a short list (curated dataset for demo) of budget stay and food options within ~2 km, sorted by distance.

### FR-6 — Live map + itinerary UI
- Render the active itinerary, current leg, and any live reroute/alert events on a map (Mapbox), with a simple timeline view of legs.

---

## 7. Hackathon Demo Scope (explicit — read before building)

We are **not** attempting live IRCTC/city-transit integration. This is a deliberate, disclosed scope decision, not a shortcut:

| In demo scope | Explicitly out of demo scope |
|---|---|
| Curated static dataset for 2–3 real routes in one demo city | Live GTFS/IRCTC feeds (unreliable/unofficial in India) |
| Simulated delay trigger (manually fireable for the demo) | Real-time bus/train polling |
| Manually seeded safety-zone dataset | Crowdsourced live safety data |
| Real Twilio/WhatsApp API call (this must be real, not mocked) | Payment/booking integrations |
| Static curated PG/food list for demo city | Live Google Places integration (nice-to-have, not required) |

This scope split is intentional so the live demo has **zero dependency on flaky third-party APIs**.

---

## 8. Success Metrics

**Demo-day metrics:**
- Cold-start to first itinerary: < 3 seconds
- Reroute trigger to updated itinerary shown: < 2 seconds
- Safety trigger to SOS delivered: < 5 seconds (real Twilio call, not simulated)

**Product-vision metrics (post-hackathon, not required for demo):**
- % of trips completed without manual re-planning
- Time-to-alert for safety triggers in the field
- User-reported trust score for autonomous actions

---

## 9. Assumptions & Constraints

- Demo city and 2–3 specific routes must be locked before AI_PIPELINE.md and DATABASE.md are finalized (data depends on this choice).
- All LLM calls must work within free-tier rate limits (Groq / Gemini 1.5 Flash).
- No component may have a hard runtime dependency on a paid or enterprise-only API.

---

## 10. Open Decisions (must be resolved before ARCHITECTURE.md is finalized)

- [ ] Confirm demo city + exact routes
- [ ] Confirm LLM provider priority order (Groq primary, Gemini fallback, or vice versa)
- [ ] Confirm whether voice input is in v1 scope or text-only

---

*Next doc: `AGENTS.md` — defines how an AI coding agent (OpenCode) should work inside this repo, referencing the scope defined above.*