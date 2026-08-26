## 02_PERSON_B — Flutter Client

> **You own:** everything in `mobile/`. All 5 screens, the map, the SSE consumer, state management.
> **You do not own:** backend (A), database/Twilio/deploy (C).
> **Read before starting:** `AGENTS.md` §0 (**twice** — it exists because an AI agent already scaffolded the wrong stack once), `AGENTS.md` §4 Flutter conventions, `04_CONTRACTS.md` §2 and §3, **`05_FEATURE_SPECS.md` §1.6, §2.4, §3.3 (preset chips, amenity panel, book-ride sheet — all now P3 core, not P4 polish)**.
> **You have the biggest single chunk of work.** Your buffer is thinner than A's or C's, so follow the order and don't gold-plate early screens.

**Your one job in one sentence:** when the agent decides something on its own, the judge must *see* it happen on the screen within 2 seconds, unmistakably.

### The hard rule, restated

Flutter + Dart only. No `.ts`/`.tsx`, no React, no Kotlin `@Composable`, no XML layouts, no Mapbox GL JS. The `android/` and `ios/` folders are build config only — you will essentially never write app code there (the two exceptions are permissions in `AndroidManifest.xml` and the Mapbox download token in `gradle.properties`, both in P0.2). If OpenCode starts writing a `.tsx` file, stop it and re-feed it `AGENTS.md` §0.

---

## P0 — Foundation (Hour 0:00 → 2:00)

### P0.1 — Project + dependencies (0:45 → 1:15)

```bash
cd raahi
flutter create --org com.raahi --platforms=android,ios mobile
cd mobile
flutter doctor          # resolve anything red BEFORE you write code
```

`pubspec.yaml` dependencies — pin them, and don't add anything not on this list without checking `PRD.md` §9 (free tier only):

```yaml
dependencies:
  flutter: {sdk: flutter}
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  dio: ^5.7.0
  go_router: ^14.6.2
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  mapbox_maps_flutter: ^2.6.0
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.2.2
  supabase_flutter: ^2.8.1
  intl: ^0.19.0
  url_launcher: ^6.3.1

dev_dependencies:
  flutter_test: {sdk: flutter}
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.9.0
  riverpod_generator: ^2.6.3
  flutter_lints: ^5.0.0
```

```bash
flutter pub get
```

**No `flutter_client_sse` package.** `AGENTS.md` §4 allows it, but you'll hand-roll SSE on Dio's streamed response in P2.1 — ~40 lines, and it means one less unmaintained dependency that could break `pub get` at hour 12. `AGENTS.md` §4 explicitly permits either.

### P0.2 — Mapbox setup (1:15 → 1:35)

The step that eats time if rushed. Mapbox needs **two different tokens**:

1. **Public token** (`pk.…`) → passed at runtime via `--dart-define=MAPBOX_TOKEN=`.
2. **Secret download token** (`sk.…`, scope `DOWNLOADS:READ`) → needed for Gradle to fetch the native SDK. Put it in `~/.gradle/gradle.properties` (**your home dir, never the repo** — it's a secret, per `SECURITY.md` intent):

```properties
MAPBOX_DOWNLOADS_TOKEN=sk.xxxxx
```

Then in Dart, before any map widget builds:

```dart
MapboxOptions.setAccessToken(const String.fromEnvironment('MAPBOX_TOKEN'));
```

Also `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

**DoD: a blank Mapbox map renders on the emulator by 1:35.** If it doesn't, timebox 20 more minutes, then fall back to a static `Image.asset` map placeholder and revisit at P2. Do not let Mapbox eat your P1 — a working demo with a fake map beats a beautiful map with no reroute.

### P0.3 — Structure + theme + router (1:35 → 2:00)

Build the tree from `AGENTS.md` §2 exactly: `data/{remote,local,repository}`, `domain/models`, `features/{trip_request,active_trip,safety_alert,amenities,settings}`, `shared/{widgets,theme}`, `routing/`.

`main.dart`: `ProviderScope` wrapping `MaterialApp.router`.

Theme — decide once, now, and stop thinking about it: Material 3, `ColorScheme.fromSeed(seedColor: Color(0xFF0F6E5C))` (deep teal — reads as "transit/safety", not generic-startup-purple). Define exactly four semantic colors in `shared/theme/tokens.dart` and use only these:

```dart
const cSafe    = Color(0xFF1B873F);  // safety score ≥ 0.7
const cCaution = Color(0xFFB77900);  // 0.4 – 0.7
const cRisk    = Color(0xFFC62828);  // < 0.4  + safety alerts
const cAgent   = Color(0xFF0F6E5C);  // ANY autonomous action
```

`cAgent` is a product decision, not decoration: **every autonomous agent action gets this color.** Reroute toast, agent-decision badges, the monitor-active pulse. By the third occurrence the judge has learned "teal = it did that by itself" without you explaining it.

`app_router.dart` with go_router — routes: `/` (trip request), `/trip/:id` (active), `/trip/:id/alert`, `/trip/:id/amenities`, `/settings`. No raw `Navigator.push` anywhere (`AGENTS.md` §4).

---

## P1 — Trip Request on Mock Data (Hour 2:00 → 4:00)

**You are fully independent this phase.** Use A's `mock_trip.json` (delivered at Hour 1:15). Never block on A.

### P1.1 — DTOs + domain models (2:00 → 2:45)

`data/remote/dto/` with freezed + json_serializable, mirroring `04_CONTRACTS.md` §2 exactly: `TripDto`, `LegDto`, `TripEventDto`, `PlaceDto`, `AmenityDto`, `ErrorEnvelopeDto`.

```bash
dart run build_runner watch --delete-conflicting-outputs   # leave running all 16 hours
```

Two things that will silently break you:

1. **`polyline` is `[[lat, lng]]` (lat first) per §2.3, but `mapbox_maps_flutter` wants `Position(lng, lat)` (lng first).** Flip it in **exactly one place** — a `Point` mapper in your DTO→domain layer. Never flip ad hoc at a call site. This is the #1 map integration bug and it fails silently: your route just draws in the wrong hemisphere.
2. **Timestamps arrive with `+05:30`.** Parse with `DateTime.parse()` then `.toLocal()`. Format with `DateFormat.jm()` from `intl`. Never `DateTime.now().toUtc()` anywhere in display code.

Also add `TripEventDto.type` as a **plain `String`, not an enum.** §2.5 requires unknown event types to render as a generic toast rather than crash — a Dart enum with `unknown` fallback via `@JsonValue` works too, but a raw string is 5 minutes faster and just as safe.

### P1.2 — API client + repository (2:45 → 3:15)

`raahi_api_client.dart` — Dio, one method per endpoint in `04_CONTRACTS.md` §3. Write **all 10 method signatures now**, even the ones A hasn't built; throw `UnimplementedError` in the body. Then P3 is filling in bodies, not designing an API surface at hour 9.

Dio interceptor attaches **both** auth headers unconditionally (per `04_CONTRACTS.md` §1.3):

```dart
options.headers['X-User-Id'] = await _localUserId();          // works from hour 2
final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
if (jwt != null) options.headers['Authorization'] = 'Bearer $jwt';   // ignored until C flips AUTH_MODE
```

`_localUserId()`: generate a UUID once, store in `flutter_secure_storage` (`AGENTS.md` §4 — **never `shared_preferences` for identity**).

`trip_repository.dart` takes a `bool useMock` flag from a provider. Mock mode loads `mock_trip.json` from assets. **This flag is your safety net for the entire hackathon** — if A's backend dies at hour 15, flip to mock and the UI still demos.

Base URL: `const String.fromEnvironment('API_BASE_URL')`. Android emulator → `http://10.0.2.2:8000` (per `ARCHITECTURE.md` §6). Hardcoding `localhost` here costs 30 minutes at SYNC 1.

### P1.3 — Trip Request screen (3:15 → 4:00)

`features/trip_request/`. A `ConsumerWidget` + `AsyncNotifierProvider` (`AGENTS.md` §4 — widget never touches Dio or the repository directly).

Contents:
- Multiline `TextField`, hint in Hinglish: *"Howrah se Salt Lake Sector V, ₹200, 10 baje tak"*. **Pre-fill this as the default value.** On stage you want to hit Plan, not type — and a judge who taps the field sees exactly what to type.
- **Route preference chips** (`05_FEATURE_SPECS.md` §1.6): Balanced / Fastest / Cheapest / Safest, single-select, `Balanced` default, sent as `route_preference` in `POST /trips`. ~15 minutes. This is demo beat #4 — tapping between Fastest and Safest and watching the itinerary genuinely change is what proves the scoring is real and not cosmetic.
- Mic icon `enabled: false` with tooltip "Voice — coming soon" (decision D1, `04_CONTRACTS.md` §1.1: disabled, not deleted).
- Emergency contact field (name + phone), persisted to Hive so it's pre-filled for the next run.
- "Plan my trip" button → `AsyncValue` states: loading spinner, error → `ErrorEnvelope.message`, data → `go_router` push to `/trip/:id`.
- Handle `clarification_needed` (§3.1): show the question inline with a text field, resubmit with the answer appended. **This is 15 minutes and it's a demo beat** — a judge typing a vague query and getting an intelligent follow-up instead of an error looks like real intelligence.

**DoD at SYNC 1:** flip `useMock=false`, tap Plan, real itinerary from A's backend renders. Take this to the sync.

---

## P2 — Active Trip Screen (Hour 4:00 → 7:00)

Your biggest phase. This screen is where the whole demo happens.

### P2.1 — SSE client (4:00 → 5:00)

`data/remote/sse_client.dart`. Per `AGENTS.md` §4: Dio streamed response, parse `event:`/`data:` lines manually, expose `Stream<TripEvent>` — **not a callback**.

```dart
Stream<TripEvent> connect(String tripId) async* {
  final rs = await dio.get<ResponseBody>('/trips/$tripId/events',
      options: Options(responseType: ResponseType.stream,
                       headers: {'Accept': 'text/event-stream'}));
  await for (final line in rs.data!.stream
        .transform(unit8Transformer).transform(const Utf8Decoder())
        .transform(const LineSplitter())) {
    // accumulate 'event:' / 'data:' lines; dispatch on blank line
  }
}
```

Four non-negotiables:
1. **Skip `heartbeat` events** (every 15 s per §3.2) — don't surface them to the UI.
2. **Dedupe on `event_id`.** The server replays all events on connect (§3.2), so without dedupe every reconnect re-fires your reroute toast — which looks catastrophic mid-demo.
3. **Auto-reconnect** with 2 s backoff on drop. Replay-on-connect makes this safe and free.
4. **Unknown `type` → generic info toast**, never a crash (§2.5).

Wrap in a `StreamProvider.family<TripEvent, String>` so widgets just `ref.watch`.

### P2.2 — Map + route rendering (5:00 → 6:00)

`mapbox_maps_flutter`:
- `PolylineAnnotationManager` — one line per leg, **colored by leg `safety_score`** using your three semantic colors. A judge instantly sees "the middle bit is amber."
- `PointAnnotationManager` — origin, destination, transfer points.
- `CircleAnnotation` or a fill layer for seeded `safety_zones` — semi-transparent `cRisk`. **Seeing the red zone on the map before entering it is what makes the safety alert land.**
- `flyTo` to fit the route bounds on load.

Remember the lat/lng flip from P1.1.

### P2.3 — Leg timeline + monitor indicator (6:00 → 6:40)

Bottom sheet (`DraggableScrollableSheet`), one card per leg: mode icon, from → to, cost, duration, depart–arrive, instruction, safety dot. Current leg highlighted; completed legs dimmed with a check.

Header: total cost vs budget (`₹47 / ₹200`) and ETA vs target (`9:52 → target 10:00 ✓`).

**A small pulsing `cAgent` dot labeled "Monitoring"** while the trip is active. It makes the invisible loop visible — the judge understands something is *watching* before anything happens. Cheap to build, disproportionate payoff.

### P2.4 — Wire real SSE (6:40 → 7:00)

Connect the stream to the screen. Handle `leg_started`/`leg_completed` by updating leg status.

**DoD at SYNC 2:** A publishes a test event from a Python shell; your UI reacts visibly within 2 s.

---

## P3 — Reroute + Alert UI (Hour 7:00 → 10:30)

This phase is the pitch. Give it your best work.

### P3.1 — Simulate buttons (7:00 → 7:20)

Two buttons on the Active Trip screen. Style them as an obvious **demo control strip** — dashed border, small "DEMO" label. Don't hide them: a judge seeing a labeled demo trigger reads as honest scoping; a judge *discovering* a hidden trigger reads as deception.

`POST /trips/{id}/simulate/delay` and `/simulate/zone-entry`. Both fire-and-forget → 202. **The UI must not optimistically update.** The change must arrive over SSE from the agent loop, because that's the truthful claim you're making on stage.

### P3.2 — Reroute event handling (7:20 → 8:30)

On `reroute` (`payload`: `old_legs`, `new_legs`, `cost_delta_inr`, `eta_delta_min`):

1. **`cAgent` toast/banner, ~5 s:** *"Route updated — bus delayed 18 min, switched to auto. +₹15, ETA still 9:58."* Use the server's `title`/`message` (§2.5 rule) — A wrote them to be display-ready.
2. **Animate the map**: fade out the old polyline, draw the new one. `AnimatedOpacity`/`AnimatedSwitcher` is enough — 400 ms. The visual change is what sells autonomy; an instant swap looks like a page reload.
3. **Timeline updates** with changed legs briefly flashing `cAgent`.
4. **"Why did this change?" chip** → bottom sheet with the reason, the old vs new comparison, and the cost/ETA delta. Judges *will* ask "how do you know it did the right thing?" — answering with a tap is much stronger than answering verbally.

### P3.3 — Safety alert screen (8:30 → 9:45)

`features/safety_alert/`. Full-screen takeover on `safety_alert` — `cRisk`, unmissable:

- "You've entered a flagged area — {zone_name}"
- "Emergency contact {name} notified" + a checkmark when `contact_notified == true` (**show the state honestly** — if Twilio failed, `contact_notified` is `false` and you must show a retry, not a fake tick)
- Live coordinates + a "Open map" button via `url_launcher` on the `map_link`
- Big "I'm safe" dismiss, and a "Call now" button that dials the contact
- Haptic feedback (`HapticFeedback.heavyImpact()`) + a sound. **Do this** — on stage, the phone buzzing at the same moment as the SMS phone is the single most memorable second of the demo.

Manual SOS FAB on Active Trip → `POST /trips/{id}/sos` (`PRD.md` FR-4 fallback).

### P3.4 — Amenity panel (9:45 → 10:15) — CORE, not polish

`05_FEATURE_SPECS.md` §2.4. Moved out of P4 because it's a pitch point (demo beat #6).

`features/amenities/` — a tab or second sheet on Active Trip. `GET /amenities?trip_id=&kind=&near=`. Card per amenity: name, kind icon, `₹price`, `walk_min`, verified badge, call button (`url_launcher` `tel:`).

Two things that carry the whole feature:

1. **Render the `reason` string prominently** — *"Verified, ₹350, 8 min walk on a lit main road."* A's server generates it. This is what makes the list read as a recommendation instead of search results.
2. **Show `budget_remaining_inr` in the panel header** — *"₹153 left"*. Then the fact that every option is under it becomes visibly meaningful rather than something you have to explain.

Colour the `path_safety` dot with your three semantic colors. The demo beat depends on a cheaper option visibly ranking *below* a pricier one because its walk is risky — C seeded a row specifically for this, so make sure your sort order is the server's `score`, not price.

### P3.5 — Book-ride sheet (10:15 → 10:30) — CORE, not polish

`05_FEATURE_SPECS.md` §3.3. On `auto`/`rideshare` leg cards, a "Book ride" button → bottom sheet listing `ride_options` sorted by `est_inr`: provider name, `₹est`, "opens in app" note.

```dart
Future<void> openRide(RideOption o) async {
  final native = Uri.parse(o.deepLink ?? '');
  if (o.deepLink != null && await canLaunchUrl(native)) {
    await launchUrl(native);
  } else {
    await launchUrl(Uri.parse(o.webFallback), mode: LaunchMode.externalApplication);
  }
}
```

**Add the `<queries>` block to `AndroidManifest.xml` now** (§3.3) — on Android 11+, `canLaunchUrl` returns false for undeclared schemes *even when the app is installed*. That's a real 20-minute trap and it only shows up on a physical device.

Label estimates as **"est."** in the UI — never as a live fare quote.

**The emulator has no cab apps installed, so it always hits the web fallback. That's expected.** Demo this on the real phone, or narrate "on a real device this opens Uber directly."

### P3.6 — Full-chain rehearsal (before SYNC 3)

Run it yourself: type query → itinerary → switch presets → simulate delay → reroute visible → open amenity panel → tap Book ride → simulate zone entry → alert screen + real SMS. Arrive at SYNC 3 with this working.

---

## P4 — Polish (Hour 10:30 → 14:00)

In order. Stop when the clock says stop. (Amenity panel and book-ride moved to P3 — see `05_FEATURE_SPECS.md` §4.)

- **P4.1 Empty/error/loading states (10:30→11:05).** Every `AsyncValue.error` renders `ErrorEnvelope.message`, never a red Flutter crash screen. Special-case `NO_ROUTE_UNDER_BUDGET`: *"Nothing under ₹200 — cheapest is ₹247. Raise your budget?"* with a one-tap raise. **A judge will test a ₹20 budget.**
- **P4.2 Supabase anon auth (11:05→11:35).** With C: `Supabase.initialize(...)` in `main()`, `signInAnonymously()` on first launch. Your interceptor already sends the JWT (P1.2), so this is initialization only. If it fights you for 20+ minutes, drop it — `X-User-Id` works and this is a nice-to-have.
- **P4.3 Trip complete + settings (11:35→12:00).** Summary (cost, duration, reroutes, alerts, and the `amenity_hint` if A sent one) and a settings screen (emergency contact, budget default, backend URL — **the URL field is genuinely useful when venue Wi-Fi forces a base-URL change at hour 15**).
- **P4.4 Polish pass (12:00→13:20).** Animations, spacing, the `cAgent` colour applied consistently to every autonomous action. Run the demo 5× and fix what looks wrong. This is your buffer — if P1–P3 ran long, this is what absorbs it.
- **P4.5 Two widget tests (13:20→14:00).** `AGENTS.md` §5 requires them: (1) Trip Request renders and submits, (2) Active Trip renders a reroute event correctly. Two, not twenty.

---

## P5 — Lock (14:30 → 16:00)

Repo frozen. Build a **release-mode APK** and install it on the demo phone:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=... --dart-define=MAPBOX_TOKEN=...
```

Debug mode's jank and the red error overlay on stage are unnecessary risks. Test the release build — release-only bugs (obfuscation vs. `json_serializable`, missing `INTERNET` permission) are real and you want to find them at 14:45, not 15:55.

---

## Your Handoffs

| Hour | You give | To |
|---|---|---|
| 4:00 | app hitting real `POST /trips` | SYNC 1 |
| 7:00 | UI reacting to live SSE events | SYNC 2 |
| 10:30 | full visible demo chain | SYNC 3 |
| 15:00 | release APK on the demo phone | C, for the runsheet |

## What You Need From Others

| Hour | You need | From | If it's late |
|---|---|---|---|
| 1:15 | `mock_trip.json` | A | **Ask immediately** — you're idle without it. Worst case write it yourself from `04_CONTRACTS.md` §2.2. |
| 4:00 | `POST /trips` live | A | Stay on `useMock=true`, keep building P2 |
| 7:00 | SSE stream live | A | Build P2.1 against a fake local `Stream` that emits your mock events on a timer — genuinely useful for testing the reroute animation on repeat |
| 12:15 | Supabase URL + anon key | C | Skip P4.3, it's a nice-to-have |