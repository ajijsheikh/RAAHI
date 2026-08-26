import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/trip_cache.dart';
import '../../../data/remote/raahi_api_client.dart';
import '../../../data/remote/sse_client.dart';
import '../../../domain/models/trip.dart';
import '../../../domain/models/trip_event.dart';
import '../../trip_request/provider/trip_request_provider.dart';

enum ActiveTripStatus { idle, loading, loaded, error }

class ActiveTripUiState {
  const ActiveTripUiState({
    required this.status,
    this.trip,
    this.errorMessage,
    this.events = const [],
    this.lastAlert,
    this.rerouteCount = 0,
  });

  final ActiveTripStatus status;
  final Trip? trip;
  final String? errorMessage;

  /// Live events as they arrive over SSE (oldest first).
  final List<TripEvent> events;

  /// Most recent safety_alert event (screen navigates on change).
  final TripEvent? lastAlert;

  /// Number of agent reroutes — feeds the "Monitoring" credibility UI.
  final int rerouteCount;

  ActiveTripUiState copyWith({
    Trip? trip,
    String? errorMessage,
    List<TripEvent>? events,
    TripEvent? lastAlert,
    int? rerouteCount,
    bool clearError = false,
  }) {
    return ActiveTripUiState(
      status: status,
      trip: trip ?? this.trip,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      events: events ?? this.events,
      lastAlert: lastAlert ?? this.lastAlert,
      rerouteCount: rerouteCount ?? this.rerouteCount,
    );
  }
}

class ActiveTripNotifier extends StateNotifier<ActiveTripUiState> {
  ActiveTripNotifier({
    required RaahiApiClient apiClient,
    required TripCache cache,
    required SseClient sse,
  })  : _api = apiClient,
        _cache = cache,
        _sse = sse,
        super(const ActiveTripUiState(status: ActiveTripStatus.idle));

  final RaahiApiClient _api;
  final TripCache _cache;
  final SseClient _sse;
  StreamSubscription<TripEvent>? _sub;

  Future<void> loadFromCache() async {
    if (state.status == ActiveTripStatus.loading ||
        state.status == ActiveTripStatus.loaded) {
      return; // already loading/loaded — avoids duplicate SSE subscriptions
    }
    final cached = _cache.activeTrip;
    if (cached == null) {
      state = const ActiveTripUiState(
        status: ActiveTripStatus.error,
        errorMessage: 'No active trip found.',
      );
      return;
    }
    state = ActiveTripUiState(status: ActiveTripStatus.loaded, trip: cached);
    _listenEvents(cached.tripId);
  }

  void _listenEvents(String tripId) {
    _sub?.cancel();
    _sub = _sse.connect(tripId).listen(
          _onEvent,
          onError: (_) {/* auto-reconnect lives inside SseClient */},
          cancelOnError: false,
        );
  }

  void _onEvent(TripEvent event) {
    switch (event.eventType) {
      case 'safety_alert':
        state = state.copyWith(events: [...state.events, event], lastAlert: event);
      case 'reroute':
        state = state.copyWith(
          events: [...state.events, event],
          rerouteCount: state.rerouteCount + 1,
        );
      case 'leg_completed' || 'leg_started':
        // Refresh trip so the leg timeline reflects reality.
        final id = state.trip?.tripId;
        if (id != null && id.isNotEmpty) {
          _api.getTrip(id).then((fresh) {
            if (mounted) state = state.copyWith(trip: fresh);
          }).catchError((_) {});
        }
        state = state.copyWith(events: [...state.events, event]);
      default:
        // Unknown types render as generic feed entries, never crash (§2.5).
        state = state.copyWith(events: [...state.events, event]);
    }
  }

  Future<void> simulateDelay(String tripId) async {
    try {
      await _api.simulateDelay(tripId: tripId, legIndex: 1, delayMinutes: 20);
    } catch (_) {
      // fire-and-forget demo trigger; result arrives via SSE
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final sseClientProvider = Provider<SseClient>((ref) {
  return SseClient(Dio(), ref.watch(raahiApiClientProvider));
});

final activeTripProvider =
    StateNotifierProvider<ActiveTripNotifier, ActiveTripUiState>((ref) {
  return ActiveTripNotifier(
    apiClient: ref.watch(raahiApiClientProvider),
    cache: ref.watch(tripCacheProvider),
    sse: ref.watch(sseClientProvider),
  );
});
