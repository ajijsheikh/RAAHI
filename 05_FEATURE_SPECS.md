## 05_FEATURE_SPECS.md — The Three Pitch-Critical Features

> **Why this file exists:** `01_PERSON_A` specified the routing algorithm but under-specified the other two — stay/food was filed as P4 polish and cab booking was one word (`deep_links.py`). All three are core pitch points, so all three get a real spec here. **This file supersedes the P4 ordering in the person-files; see §4 for the corrected phase placement.**
>
> **Precedence:** `04_CONTRACTS.md` > this file > person-files.

---

## 1. Routing Algorithm — Multi-Objective Time-Dependent Search

### 1.1 What we're actually solving

"Fastest route" is the wrong framing for Raahi, and saying so is part of the pitch. Google Maps already solves fastest. Raahi solves **"best route for *this* person, with ₹200, arriving by 10:00, alone, at night"** — which is a multi-objective problem where fastest is one of four competing objectives.

So the algorithm is not Dijkstra-on-time. It's **k-shortest-paths generation followed by multi-objective scoring**, and the two-stage split is deliberate: stage 1 finds structurally distinct options fast, stage 2 applies preferences that a single edge weight can't express (like "a route is only as safe as its worst leg").

### 1.2 The graph

Built once at startup from `transit_stops` + `transit_routes`, cached in memory. It's ~12 nodes and ~20 edges (Person C's seed) — small enough that everything below runs in single-digit milliseconds.

- **Nodes** = `transit_stops`
- **Edges** = `transit_routes`, one per (from, to, mode). Parallel edges are expected and wanted — Bidhannagar→Sector V exists as both `auto` (₹37/18min) and `bus` (₹12/20min), and having both is what makes the planner's choice meaningful.
- **Implicit walk edges:** any two stops within 900 m get a synthetic `walk` edge at 12 min/km, ₹0. This is what lets the planner produce "get off here and walk 6 minutes" instead of insisting on a paid last leg. Generate these at graph-build time with one PostGIS query:

```sql
SELECT a.id, b.id, ST_Distance(a.geom, b.geom) AS m
FROM transit_stops a JOIN transit_stops b ON a.id < b.id
WHERE ST_DWithin(a.geom, b.geom, 900);
```

### 1.3 Edge cost is time-dependent (this is the part that's genuinely non-trivial)

A transit edge's real cost depends on *when you arrive at the stop*, because you wait for the next departure. Ignoring wait time is the most common hackathon routing bug: the planner returns a 2-transfer route that's "faster" on paper but actually loses 25 minutes standing at bus stops.

```python
def edge_traversal(edge, arrival_at_node: datetime) -> tuple[datetime, int]:
    """Returns (arrival at next node, wait_minutes)."""
    if edge.mode in ("walk", "auto", "rideshare"):
        return arrival_at_node + timedelta(minutes=edge.duration_min), 0   # on-demand, no wait
    if not (edge.first_dep <= arrival_at_node.time() <= edge.last_dep):
        return UNREACHABLE, 0        # service not running — critical for late-night routes
    wait = next_departure(edge, arrival_at_node) - arrival_at_node          # headway-based
    return arrival_at_node + wait + timedelta(minutes=edge.duration_min), wait.minutes
```

`next_departure` uses `headway_min` (expected wait = headway/2 on average, but model worst case = full headway for ETA safety — under-promising on arrival time is the right bias for someone who has a deadline).

The `first_dep`/`last_dep` check matters more than it looks: a 10 PM query must not return "take the 6 AM local." Person C seeded those columns for exactly this reason.

### 1.4 Stage 1 — candidate generation (Yen's k-shortest paths, k=4)

Run modified Dijkstra with **arrival time** as the label (not distance), respecting §1.3. Then Yen's algorithm for the next 3 alternatives, with two constraints:

- **Max 2 transfers.** More than 2 is a route nobody actually takes, and it explodes the search space.
- **Diversity filter:** reject a candidate that shares >70% of its edges with an already-accepted one. Without this, k=4 returns four near-identical routes and stage 2 has nothing real to choose between. This is what guarantees the demo shows genuinely different options.

Also generate, unconditionally:
- The **cheapest** path (Dijkstra on `cost_inr`) — often ignored by time-first search but it's the one that saves a tight budget.
- The **safest** path (Dijkstra on `1 - leg_safety`) — the route a solo traveler at 11 PM actually wants.

So you end up with up to 6 structurally distinct candidates. On 12 nodes this is ~5 ms.

### 1.5 Stage 2 — multi-objective scoring

Per `01_PERSON_A` P1.3, with the weights now made switchable:

```python
def score(it, budget, target_eta, weights) -> float:
    if it.total_cost_inr > budget:          return -inf   # HARD, PRD FR-2
    if it.arrive_at > target_eta:           return -inf   # HARD, misses the deadline
    if it.arrive_at is UNREACHABLE:         return -inf   # service not running

    cost_term     = 1 - (it.total_cost_inr / budget)
    time_term     = 1 - min(it.total_duration_min / 120, 1.0)
    transfer_term = 1 - min(it.transfers / 3, 1.0)
    safety_term   = it.safety_score                        # min across legs, not mean
    slack_term    = min((target_eta - it.arrive_at).minutes / 30, 1.0)   # buffer is a feature

    return (weights.cost*cost_term + weights.time*time_term +
            weights.transfer*transfer_term + weights.safety*safety_term +
            weights.slack*slack_term)
```

Two design points worth defending on stage:

**`safety_score` is `min()` across legs, never mean.** A route that's perfectly safe for 90% of its length and terrifying for 10% is a terrifying route. Averaging hides exactly the thing the user cares about.

**`slack_term` rewards arriving early.** Two routes both arriving before 10:00 are not equally good — one arriving 9:52 survives an 8-minute delay, one arriving 9:59 doesn't. This is also what makes the delay watcher's decision in §1.7 non-arbitrary.

### 1.6 User-selectable presets (the "fastest route" answer)

This is how "fastest route" becomes a real, visible feature rather than an implementation detail. Four presets, exposed as chips on the Trip Request screen:

| Preset | cost | time | transfer | safety | slack | When it wins |
|---|---|---|---|---|---|---|
| **Balanced** (default) | 0.25 | 0.20 | 0.10 | 0.30 | 0.15 | general use |
| **Fastest** | 0.05 | 0.55 | 0.15 | 0.15 | 0.10 | "I'm late" |
| **Cheapest** | 0.55 | 0.10 | 0.05 | 0.20 | 0.10 | tight budget |
| **Safest** | 0.10 | 0.15 | 0.05 | 0.60 | 0.10 | travelling alone at night |

Weights live in `config.py`, preset passed as `route_preference` in `POST /trips` (default `balanced`).

**Demo value:** tapping between Fastest and Safest and watching the itinerary *actually change* — different modes, different cost, different map — is a 15-second beat that proves the scoring is real and not cosmetic. Person C's seed data must support this: there needs to be a fast-but-riskier option and a slow-but-safer one on Route 1. That's now a seed-data requirement, not a nice-to-have.

**Auto-suggest:** if `parse_intent` finds departure after 20:00 and no explicit preference, default to **Safest** and tell the user why ("It's late — I optimised for safety over speed"). An agent that changes its own objective function based on context is a stronger claim than one that just follows orders.

### 1.7 Replanning uses the same machinery

On a delay trigger, replan is not a different algorithm — it's the same two stages with `origin = current position`, `budget = ceiling - spent`, same target ETA. The watcher's trigger condition is the interesting part (`01_PERSON_A` P2.4): it fires only when the delay actually threatens the connection or the ETA, which is exactly the `slack_term` from §1.5 going negative.

### 1.8 Complexity + honest limits

~12 nodes, ~20 edges: Dijkstra is O(E log V) ≈ trivial; Yen's k=4 is 4 Dijkstra runs. Total planning time is dominated entirely by the LLM intent-parse call (~600 ms), not the search (~5 ms). That's worth saying if asked "does it scale?" — the honest answer is: this search scales to a full city graph fine (it's standard k-shortest-paths), what doesn't scale is our curated dataset, and that's a data problem we deliberately scoped (`PRD.md` §7).

**Tests required** (extends `AGENTS.md` §5): over-budget rejected · misses-ETA rejected · safest-preset beats faster-unsafe route · service-hours edge excluded at 23:30 · diversity filter rejects near-duplicate.

---

## 2. Stay & Food — The Amenity Agent

### 2.1 Why this is not just a nearby-places list

`PRD.md` FR-5 says "return a short list sorted by distance," which is what Google Maps does and is not worth pitching. The upgrade, and the reason this is a *feature* and not a query: **the amenity recommendation is budget-aware, safety-aware, and route-aware.**

Three things no maps app does:

1. **It knows what money is left.** After a ₹47 trip on a ₹200 budget, the ₹153 remaining is the actual constraint on a hostel — so we filter by *remaining* budget, not total.
2. **It knows whether the walk there is safe.** A ₹300 PG 400 m away through a flagged zone scores worse than a ₹350 PG 700 m away on a lit main road. This uses the same `safety_zones` data as the routing safety score — one dataset, two features, which is a good architecture story.
3. **It knows where you'll be on the route.** For a stay, "near the destination" is right. For food, "near where I'll be around 1 PM" is right — which may be a mid-route transfer point, not the destination.

### 2.2 The scoring function

```python
def amenity_score(a, budget_remaining, arrive_time, kind) -> float:
    if a.price_inr > budget_remaining:  return -inf     # hard, same discipline as routing

    price_term    = 1 - (a.price_inr / budget_remaining)
    distance_term = 1 - min(a.walk_m / 1500, 1.0)
    safety_term   = walk_path_safety(a)                 # PostGIS: straight line vs safety_zones
    quality_term  = (a.rating or 3.0) / 5.0
    verified_term = 1.0 if a.verified else 0.55         # unverified is usable, not equal

    if kind == "stay":
        return 0.25*price_term + 0.20*distance_term + 0.30*safety_term + 0.15*quality_term + 0.10*verified_term
    else:  # food
        return 0.30*price_term + 0.35*distance_term + 0.20*safety_term + 0.15*quality_term
```

Stay weights safety highest (you're sleeping there, and you walk there at night). Food weights distance highest (you're hungry now and coming back). Same shape as the routing scorer on purpose — one scoring idiom across the whole product, easy to explain in one sentence.

`walk_path_safety` is deliberately crude: straight line from route endpoint to amenity, intersected against `safety_zones`, `1 - max(base_risk × night_multiplier)`. Not a real walking route — and say that if asked. It's directionally correct and it costs 10 lines.

### 2.3 The agentic bit (what makes this more than an endpoint)

Two behaviours that make this an agent feature rather than a search box:

**Proactive stay suggestion.** If `parse_intent` detects arrival after 21:00 with no return trip mentioned, the agent surfaces stay options *unprompted* on trip completion, as a `trip_completed` event with an `amenity_hint` payload: *"You're arriving at 21:40. Want somewhere to stay? 3 verified PGs under ₹400 within 900 m."* Nobody asked. That's the product.

**Budget-linked re-filter.** When the budget watcher fires a `budget_switch` (trip got more expensive), the amenity list silently re-filters to the new remaining budget. The stay list at ₹153 remaining and at ₹120 remaining are different lists, and it updates itself.

### 2.4 API

Extends `04_CONTRACTS.md` §3 endpoint 8:

```
GET /amenities?trip_id=&kind=stay|food&near=leg_end|destination&limit=5
→ { "amenities": [ { ...AmenityDto, "walk_m": 640, "walk_min": 8,
                     "path_safety": 0.71, "score": 0.68,
                     "reason": "Verified, ₹350, 8 min walk on a lit main road" } ],
    "budget_remaining_inr": 153 }
```

**`reason` is a required field, not decoration.** One human-readable line per recommendation, template-generated (no LLM call — keep it deterministic and fast). It's what turns a list into a recommendation, and it's what a judge reads out loud.

### 2.5 Data requirement (Person C)

Bumped from ~10 rows to **~16**, and the distribution matters more than the count:

- 8 stay near Sector V + Park Street: ₹250–900, at least 5 `verified`, **at least one deliberately placed inside/adjacent to a flagged zone** so the safety term visibly demotes a cheap option. Without that row, safety-aware ranking is invisible and unprovable.
- 8 food: ₹30–180, spread across the destination and one mid-route transfer point (Bidhannagar Road) so `near=leg_end` returns something different from `near=destination`.

---

## 3. Cab & Taxi — Deep-Link Handoff

### 3.1 The scope decision, stated honestly

`PRD.md` §4 non-goals: **no in-app payments or ticket booking.** That stands — and it's the right call, not a cop-out. Uber/Ola/Rapido booking APIs require partner agreements, business verification, and revenue-share contracts. There is no free-tier path to programmatic ride booking in India in 16 hours, and any demo claiming otherwise is faking it.

What we do instead is the same thing every real travel app does: **deep-link handoff with the ride pre-filled.** The user taps once, the cab app opens with pickup and drop already set, and they confirm in the app that has their payment method and their account. Raichi orchestrates; it doesn't intermediate the transaction.

Frame it that way on stage — "we hand off to the app that already has your card, with the ride pre-filled" — and it reads as a deliberate product boundary. That's a stronger answer than a fake booking screen.

### 3.2 The deep links

`backend/app/services/deep_links.py`. Every `auto` or `rideshare` leg gets a `deep_link` populated (the field already exists in `04_CONTRACTS.md` §2.3 — it's currently always `null`, which is the gap).

```python
def uber(from_lat, from_lng, to_lat, to_lng, to_name) -> str:
    return ("uber://?action=setPickup"
            f"&pickup[latitude]={from_lat}&pickup[longitude]={from_lng}"
            f"&dropoff[latitude]={to_lat}&dropoff[longitude]={to_lng}"
            f"&dropoff[nickname]={quote(to_name)}")

def ola(...)     -> "olacabs://app/launch?lat=&lng=&drop_lat=&drop_lng="
def rapido(...)  -> "rapido://..." if installed else the Play Store / web URL
def gmaps(...)   -> ("https://www.google.com/maps/dir/?api=1"
                     f"&origin={from_lat},{from_lng}&destination={to_lat},{to_lng}"
                     "&travelmode=driving")   # universal fallback, always works
```

Return **a list of options**, not one:

```json
"ride_options": [
  {"provider":"uber",   "deep_link":"uber://...",     "web_fallback":"https://m.uber.com/...", "est_inr":180},
  {"provider":"ola",    "deep_link":"olacabs://...",  "web_fallback":"...",                    "est_inr":165},
  {"provider":"rapido", "deep_link":"rapido://...",   "web_fallback":"...",                    "est_inr":95},
  {"provider":"gmaps",  "deep_link":null,             "web_fallback":"https://maps.google...", "est_inr":null}
]
```

`est_inr` comes from our own `transit_routes` cost estimate for that leg — **label it "est." in the UI.** Do not present a made-up number as a live fare quote; if a judge asks, the honest answer is "our estimate from local fare data, the real quote comes from the provider on the next screen."

### 3.3 Flutter side (Person B)

`url_launcher` with the standard try-native-then-web pattern:

```dart
Future<void> openRide(RideOption o) async {
  final native = Uri.parse(o.deepLink ?? '');
  if (o.deepLink != null && await canLaunchUrl(native)) {
    await launchUrl(native);                                    // app installed
  } else {
    await launchUrl(Uri.parse(o.webFallback),
                    mode: LaunchMode.externalApplication);       // browser / store
  }
}
```

**Test on the demo device early (Person B, P2).** `canLaunchUrl` on Android 11+ requires the schemes declared in `AndroidManifest.xml` or it returns false even when the app *is* installed — this is a real 20-minute trap:

```xml
<queries>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="uber"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="olacabs"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="rapido"/></intent>
</queries>
```

UI: on an `auto`/`rideshare` leg card, a "Book ride" button → bottom sheet with the options sorted by `est_inr`, each showing provider, estimate, and an "opens in app" note. **The emulator has no cab apps installed, so it will always hit the web fallback — that's fine and expected. Demo this on the real phone**, where at least one cab app is installed, or explicitly narrate "on a real device this opens Uber directly."

### 3.4 The agentic connection (why this isn't just a button)

The budget watcher (`01_PERSON_A` P4.1) already substitutes cheaper modes. Now that substitution has a real destination: when a leg's `auto` cost would breach the ceiling, the agent switches to `bus` **and** re-populates `ride_options` with the cheaper providers (Rapido bike over Uber sedan). The `budget_switch` event message becomes concrete: *"Auto would put you ₹40 over. Switched to bus — or tap for a Rapido bike at ₹95."*

That's the difference between a booking button and an agent that manages your budget across modes.

---

## 4. Corrected Phase Placement

These features were mis-scoped in the person-files. Corrected placement, with hours rebalanced to still total 16:

| Feature | Was | Now | Owner |
|---|---|---|---|
| Time-dependent edges + k-shortest + diversity | folded vaguely into P1.3 | **A P1.3, explicitly** (3:00→3:40) | A |
| Route presets (Fastest/Cheapest/Safest) | absent | **A P1.3b** (3:40→3:50) + chips in **B P1.3** (3:15→4:00) | A + B |
| Seed data that makes presets differ | absent | **C P1.2b** (3:15→3:25) | C |
| Amenity agent + scoring + `reason` | A P4.3 polish (11:45) | **A P3.5 core** (9:15→10:00) | A |
| Amenity panel UI | B P4.1 polish (10:30) | **B P3.4 core** (9:45→10:15) | B |
| 16 amenity rows w/ one in a flagged zone | C P1.4, ~10 rows | **C P1.4 expanded** (3:50→4:20) | C |
| `deep_links.py` + `ride_options` | one word, unscheduled | **A P3.6** (10:00→10:30) | A |
| Book-ride sheet + manifest `<queries>` | absent | **B P3.5** (10:15→10:30) | B |

**Corrected cut list** (replaces `00_MASTER_PLAN.md` §1 — the old one had amenities at #4, which was wrong given these are pitch points):

1. widget tests beyond two
2. trip-complete screen
3. settings screen
4. Supabase deploy → fall back to laptop + hotspot
5. budget watcher *(but keep `ride_options`, it's cheap and it's a pitch point)*
6. route presets down to two chips (Fastest + Safest only)
7. proactive stay suggestion (keep the `/amenities` endpoint + panel)

**Protected — do not cut, these are the pitch:** NL→itinerary, autonomous reroute, real Twilio SOS, amenity list with budget+safety reasoning, `ride_options` on cab legs.

**What paid for the added hours:** A's P4.2 error envelopes trimmed to 20 min (5 codes, one handler), P4.5 hardening 75→60 min. B's P4.2 states 45→35 min, P4.4 trip-complete+settings 35→25 min (both already on the cut list anyway). C's optional WhatsApp slot (P2.4) absorbed into the expanded seed data — SMS working reliably was always worth more than WhatsApp.

---

*Read this alongside your person-file. Where the person-file's P4 ordering disagrees with §4 above, §4 wins.*