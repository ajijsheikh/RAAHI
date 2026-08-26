import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raahi/data/remote/raahi_api_client.dart';
import 'package:raahi/data/remote/sse_client.dart';
import 'package:raahi/data/local/trip_cache.dart';
import 'package:raahi/domain/models/trip.dart';
import 'package:raiah/domain/models/itinerary.dart';

import 'active_trip_screen.dart';

final activeTripProvider =
    StateNotifierProvider<ActiveTripNotifier, ActiveTripUiState>((ref) {
  final apiClient = ref.watch(raahiApiClientProvider);
  final cache = ref.watch(tripCacheProvider);
  return ActiveTripNotifier(
    apiClient: apiClient,
    cache: cache,
    sseClient: ref.watch(sseClientProvider),
  );
});

class ActiveTripNotifier extends StateNotifier<ActiveTripUiState> {
  final RaahiApiClient _apiClient;
  final TripCache _cache;
  final SseClient _sseClient;

  ActiveTripNotifier({
    required RaahiApiClient apiClient,
    required TripCache cache,
    required SseClient sseClient,
  })  : _apiClient = apiClient,
        _cache = cache,
        _sseClient = sseClient,
        super(const ActiveTripUiState.idle());

  Future<void> loadTrip(String tripId) async {
    state = const ActiveTripUiState.loading();
    try {
      final trip = await _apiClient.getTrip(tripId);
      await _cache.saveTrip(trip);
      state = ActiveTripUiState.loaded(trip);
      _startSseListener(trip.tripId);
    } on Exception catch (e) {
      state = ActiveTripUiState.error(_mapExceptionToMessage(e));
    }
  }

  Future<void> triggerDelay({required int legIndex, required int delayMinutes}) async {
    state = {...state, isTriggering: true};
    try {
      await _apiClient.simulateDelay(
        tripId: state.trip?.tripId ?? '',
        legIndex: legIndex,
        delayMinutes: delayMinutes,
      );
      // The replan result will come via SSE
      state = {...state, isTriggering: false};
    } on Exception catch (e) {
      state = {...state, isTriggering: false, error: _mapExceptionToMessage(e)};
    }
  }

  Future<void> triggerSafety({required String zoneId}) async {
    state = {...state, isTriggering: true};
    try {
      await _apiClient.simulateSafetyTrigger(
        tripId: state.trip?.tripId ?? '',
        zoneId: zoneId,
      );
      // The SSE event will arrive with the alert
      state = {...state, isTriggering: false};
    } on Exception catch (e) {
      state = {...state, isTriggering: false, error: _mapExceptionToMessage(e)};
    }
  }

  void _startSseListener(String tripId) {
    _sseClient.connect(
      onConnectionOpened: () {},
    );
    // Listen to SSE events and update state
    final stream = _sseClient.eventsStream();
    // The stream will be consumed by the widget tree via listener provider
  }

  String _mapExceptionToMessage(Exception e) {
    if (e.toString().contains('404')) return 'Trip not found.';
    if (e.toString().contains('409')) return 'No route under budget.';
    return 'An error occurred. Please try again.';
  }
}

enum ActiveTripStatus { idle, loading, loaded, error, alert, reroute }

class ActiveTripUiState {
  final ActiveTripStatus status;
  final Trip? trip;
  final String? error;
  final bool isTriggering;
  final List<TripEvent> events;
  final bool hasActiveAlert;

  ActiveTripUiState._({
    required this.status,
    this.trip,
    this.error,
    this.isTriggering = false,
    this.events = const [],
    this.hasActiveAlert = false,
  });

  factory ActiveTripUiState.idle() => const ActiveTripUiState._(
        status: ActiveTripStatus.idle,
        trip: null,
        error: null,
        isTriggering: false,
      );

  factory ActiveTripUiState.loading() => const ActiveTripUiState._(
        status: ActiveTripStatus.loading,
        trip: null,
        error: null,
        isTriggering: false,
      );

  factory ActiveTripUiState.loaded(Trip trip) => ActiveTripUiState._(
        status: ActiveTripStatus.loaded,
        trip: trip,
        error: null,
        isTriggering: false,
        events: [],
      );

  factory ActiveTripUiState.error(String message) => ActiveTripUiState._(
        status: ActiveTripStatus.error,
        trip: null,
        error: message,
        isTriggering: false,
      );

  factory ActiveTripUiState.alert() => ActiveTripUiState._(
        status: ActiveTripStatus.alert,
        trip: null,
        error: null,
        isTriggering: false,
        hasActiveAlert: true,
      );

  factory ActiveTripUiState.reroute() => ActiveTripUiState._(
        status: ActiveTripStatus.reroute,
        trip: null,
        error: null,
        isTriggering: false,
        hasActiveAlert: true,
      );

  bool get isLoaded => status == ActiveTripStatus.loaded;
  bool get isError => status == ActiveTripStatus.error;
  bool get isAlert => status == ActiveTripStatus.alert;
  bool get isReroute => status == ActiveTripStatus.reroute;
  bool get hasEvents => events.isNotEmpty;
}