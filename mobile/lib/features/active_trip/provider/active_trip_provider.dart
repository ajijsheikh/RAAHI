import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/trip_cache.dart';
import '../../../data/remote/raahi_api_client.dart';
import '../../../domain/models/trip_event.dart';
import '../../trip_request/provider/trip_request_provider.dart';

enum ActiveTripStatus { idle, loading, loaded, error }

class ActiveTripUiState {
  const ActiveTripUiState({
    required this.status,
    this.trip,
    this.errorMessage,
    this.events = const [],
  });  final ActiveTripStatus status;
  final dynamic trip; // Trip — dynamic to avoid import cycle in this quick pass
  final String? errorMessage;
  final List<TripEvent> events;
}

class ActiveTripNotifier extends StateNotifier<ActiveTripUiState> {
  ActiveTripNotifier({
    required RaahiApiClient apiClient,
    required TripCache cache,
  })  : _api = apiClient,
        _cache = cache,
        super(const ActiveTripUiState(status: ActiveTripStatus.idle));

  final RaahiApiClient _api;
  final TripCache _cache;
  StreamSubscription<TripEvent>? _sub;

  Future<void> loadFromCache() async {
    final cached = _cache.activeTrip;
    if (cached == null) {
      state = const ActiveTripUiState(status: ActiveTripStatus.error,
          errorMessage: 'No active trip found.');
      return;
    }
    state = ActiveTripUiState(status: ActiveTripStatus.loaded, trip: cached);
    _listenEvents(cached.tripId);
  }

  void _listenEvents(String tripId) {
    _sub?.cancel();
    // TODO(P2): swap for ref-read SseClient once backend SSE endpoint lands.
    // Until then the screen renders fine without live events.
  }

  Future<void> simulateDelay(String tripId) async {
    try {
      await _api.simulateDelay(tripId: tripId, legIndex: 1, delayMinutes: 20);
    } catch (_) {
      // fire-and-forget demo trigger
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final activeTripProvider =
    StateNotifierProvider<ActiveTripNotifier, ActiveTripUiState>((ref) {
  return ActiveTripNotifier(
    apiClient: ref.watch(raahiApiClientProvider),
    cache: ref.watch(tripCacheProvider),
  );
});
