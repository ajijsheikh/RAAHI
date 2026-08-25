## UI_SPEC.md — Detailed Flutter Client Requirements

> **Platform note:** this is a Flutter (Dart) mobile app, developed from Android Studio with the Flutter plugin. See AGENTS.md §0 before touching this file — every "screen" below is one widget + one or more Riverpod providers, not a web page/route, and not a native Android/iOS UI component.
>
> **Purpose of this doc:** what the app must render, screen by screen, and how it reacts to the API/SSE contract defined in API_SPEC.md. This is not a visual design file — no exact colors/typography mandated here beyond what's needed for state legibility (e.g. "alert state must look urgent"); a designer can skin this freely with Flutter's Material3 theming as long as the states below remain distinguishable.

---

## 1. Screen Map (Navigation Graph)

```
1. Trip Request Screen   → 2. Planning (loading) State → 3. Active Trip Screen
                                                                │
                                                    ┌───────────┼───────────┐
                                                    ▼           ▼           ▼
                                         4. Reroute Toast  5. Safety Alert  6. Amenity Panel
                                                    │
                                                    ▼
                                         7. Trip Complete Screen
```

Plus a persistent **Settings / Emergency Contact** screen reachable from anywhere via the app's route configuration.

**Navigation:** `go_router`. Each screen is a named route in `routing/app_router.dart`; Screen 2 (loading) is a state *within* the Trip Request route, not a separate route — don't create a dedicated route just for a loading spinner.

**State management:** each screen is backed by one or more Riverpod providers (typically an `AsyncNotifierProvider<..., UiState>` per screen, where `UiState` is a sealed class via `freezed`, e.g. `TripRequestUiState.idle() / loading() / clarificationNeeded(field) / error(message)`). Widgets `watch` this provider and rebuild based on the state — no ad-hoc `setState` scattered across widgets for anything that reflects backend/business state.

---

## 2. Screen 1 — Trip Request

**Widget:** `TripRequestScreen` (`ConsumerWidget`) · **Provider:** `tripRequestProvider`

**Purpose:** capture the natural-language query (FR-1).

**Requirements:**
- A single large `TextField` (multi-line) for the query, with `hintText` showing a realistic example query (not a generic "Enter text here").
- Optional voice input via an `IconButton` next to the field, backed by the `speech_to_text` package — if not ready by demo time, the button can remain visible but disabled (per PRD.md's open decision on voice scope — **check PRD.md before assuming this ships**).
- On submit, the provider transitions state to `loading` immediately — the widget must never show a static, unresponsive field for more than ~300ms after tapping submit.
- If the backend returns `422` (clarification needed, API_SPEC.md §1), the state becomes `clarificationNeeded(field)` and the widget shows **one** targeted follow-up `TextField` (e.g. "What's your budget?") — never render a full form of every field at once; that defeats the point of natural-language input.

---

## 3. Screen 2 — Planning (loading) State

- A state within `TripRequestScreen`, not a separate route.
- Show sequential micro-copy via a `Text` widget that updates on a `Timer`/`Future.delayed` cycle ("Understanding your trip…" → "Finding the best route…"), roughly tracking the backend's actual pipeline stages, so the wait feels explainable rather than opaque. A bare `CircularProgressIndicator` alone is not sufficient.
- Target perceived wait: under 3 seconds per PRD.md §8 — if the network call exceeds ~4 seconds, switch the copy to a reassuring "still working" message rather than letting the indicator look frozen.

---

## 4. Screen 3 — Active Trip Screen (the core screen)

**Widget:** `ActiveTripScreen` (`ConsumerWidget`) · **Provider:** `activeTripProvider`

**Layout:** a `MapWidget` (from `mapbox_maps_flutter`) as the primary surface (~65% of the screen height), with a `DraggableScrollableSheet` or fixed lower `Container` holding the itinerary timeline.

**Map requirements:**
- Render the full itinerary as a route line via Mapbox's line-layer API (through `mapbox_maps_flutter`'s style/layer bindings), with distinct styling per leg mode (walk/bus/metro/auto — represented with a legend `Row` of icon+label pairs, not color alone, for accessibility).
- Render safety-zone polygons (from `safety_zones`, DATABASE.md §3) as a fill layer if any are within the current camera bounds — subtle fill, not alarming, unless the user's live position is inside one (see Screen 5).
- Current position marker (a Mapbox point annotation) updates live if location permission is granted (`ACCESS_FINE_LOCATION` on Android / location usage description on iOS, requested via the `permission_handler` package with a clear rationale dialog shown first, given this app's core value prop depends on it).

**Timeline panel requirements:**
- Each leg rendered as a `Card` widget: mode icon, from → to, cost, scheduled time.
- The **currently active leg's** `Card` must be visually distinct (not just a color change — also elevation/emphasis via Material3's `Card` styling) from completed/upcoming legs.
- When a leg's `status` becomes `superseded` (DATABASE.md §2), don't just remove its `Card` from the `ListView`/`Column` — render it with a strikethrough `TextStyle` and show the replacement leg's `Card` immediately after, so the user sees *what changed*, not just the new state. This is what makes the agentic behavior visible/demonstrable in the UI, not just claimed in the pitch.

**SSE handling:**
- `activeTripProvider` listens to the `Stream<TripEvent>` exposed by `sse_client.dart` (AGENTS.md §4). Every event must produce a visible, non-blocking UI change within 1 second of receipt — a `SnackBar` plus the corresponding map/timeline rebuild. Never require a manual pull-to-refresh to reflect a backend-driven change.

---

## 5. Screen 4 — Reroute Toast

Triggered by an `event_type: "replan"` SSE event.

- A `SnackBar`, auto-dismiss after ~6 seconds, but the underlying timeline change (per §4) persists after the snackbar disappears.
- Copy must state the *reason*, not just the fact: "Bus delayed 18 min — switched to auto" not "Route updated."

---

## 6. Screen 5 — Safety Alert State

**Widget:** `SafetyAlertBanner`, rendered as an overlay within `ActiveTripScreen` (e.g. via a `Stack` + `Positioned` or an `AnimatedSwitcher`) — not a separate route, since the user must not lose the map context. Triggered by an `event_type: "alert"` SSE event. **This is the single most important state in the app — it must not look like a generic notification.**

- Full-width, high-contrast banner `Container` (not a dismissable `SnackBar`) confirming: zone flagged, emergency contact notified, timestamp.
- Show the emergency contact's name/relation so the user has confidence the *right* person was notified.
- Include a manual "I'm safe" `ElevatedButton` — tapping it does not undo the alert already sent (that already happened autonomously, irreversibly, by design); it only updates local UI state so the banner can be dismissed.
- The map camera should animate to and highlight the flagged zone polygon the user is currently inside, not just show a generic marker.

---

## 7. Screen 6 — Amenity Panel

**Widget:** `AmenityPanel`, shown via `showModalBottomSheet` from `ActiveTripScreen` — not a separate top-level route, since amenities are a companion to the trip, not a destination in themselves (per PRD.md, this isn't a booking platform).

- Each result rendered as a `ListTile`: name, category icon, price, distance — sorted by distance by default (API_SPEC.md §6), via a `ListView.builder`.
- No booking/payment CTA — link-out is out of scope (PRD.md §4 non-goals). If a link exists (opened via `url_launcher`), it should be clearly labeled "more info," never implying in-app booking.

---

## 8. Screen 7 — Trip Complete

**Widget:** `TripCompleteScreen`

- Simple confirmation screen once the destination leg is marked complete — a summary `Card` showing total cost vs. budget ceiling (reinforces the budget-adherence value prop), and a count of autonomous actions taken during the trip (e.g. "1 reroute, 0 alerts") pulled from `trip_events` via the trip-detail endpoint.

---

## 9. Settings / Emergency Contact Screen

**Widget:** `SettingsScreen` (`ConsumerWidget`) · **Provider:** `settingsProvider`

- Single required field: emergency contact phone number, in a `TextField` with `TextInputType.phone`, validated as E.164 client-side before submit (mirroring API_SPEC.md §7's server-side validation — client validation is a UX nicety here, not a substitute for the server check, per SECURITY.md).
- Must be completable *before* a trip can enter an active safety-monitoring state — `tripRequestProvider` should check for a registered contact before allowing submission, or clearly show "safety alerts disabled — no contact set" as a persistent banner if the user proceeds without one. Never let a trip go active with no emergency contact and silently skip the safety watcher.

---

## 10. Cross-Cutting Requirements

- **No dead-end loading states.** Every async UI state has a visible in-progress variant and a visible error variant — never a screen that just does nothing on failure. Standardize on a shared `ErrorStateWidget` used across all screens for consistency.
- **Demo-safe defaults:** the simulate-delay/simulate-safety-trigger calls (API_SPEC.md §4–5) should be exposed via an obviously-labeled "Demo Controls" section (e.g. a debug-only bottom sheet gated behind `kDebugMode` from `flutter/foundation.dart`) during hackathon judging — this must be compiled out of (or hidden in) anything resembling a release build.
- **Color is never the only signal** for state (active vs superseded leg, safe vs flagged zone) — pair with icon/text, consistent with accessibility guidelines (`Semantics` labels required on all icon-only elements, especially in the safety-alert path per SECURITY.md).
- **Permissions:** location and notifications must be requested (via `permission_handler`) with clear rationale dialogs before the first trip is created — not silently requested on app launch before the user understands why.
- **Platform parity:** since Flutter targets both Android and iOS from one codebase, any platform-specific behavior (permission dialog wording, notification handling) should be abstracted behind a shared interface rather than littering `Platform.isAndroid`/`Platform.isIOS` checks through screen-level widgets.

---

*Next doc: `SECURITY.md` — credential handling, PII/location data policy, and prompt-injection defenses referenced throughout this doc and AI_PIPELINE.md.*