import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/trip_cache.dart';
import '../../../data/remote/raahi_api_client.dart';
import '../../../domain/models/trip.dart';

enum TripRequestStatus { idle, loading, success, error }

class TripRequestUiState {
  const TripRequestUiState._({
    required this.status,
    this.trip,
    this.errorMessage,
    this.clarificationQuestion,
  });

  const TripRequestUiState.idle()
      : this._(status: TripRequestStatus.idle);

  const TripRequestUiState.loading()
      : this._(status: TripRequestStatus.loading);

  const TripRequestUiState.success(Trip trip)
      : this._(status: TripRequestStatus.success, trip: trip);

  const TripRequestUiState.error(String message)
      : this._(status: TripRequestStatus.error, errorMessage: message);

  const TripRequestUiState.clarify(String question)
      : this._(
          status: TripRequestStatus.idle,
          clarificationQuestion: question,
        );

  final TripRequestStatus status;
  final Trip? trip;
  final String? errorMessage;

  /// Non-null => backend asked a follow-up (§3.1). Render inline, not as error.
  final String? clarificationQuestion;

  bool get isLoading => status == TripRequestStatus.loading;
  bool get needsClarification => clarificationQuestion != null;
}

class TripRequestNotifier extends StateNotifier<TripRequestUiState> {
  TripRequestNotifier({required RaahiApiClient apiClient, required TripCache cache})
      : _apiClient = apiClient,
        _cache = cache,
        super(const TripRequestUiState.idle());

  final RaahiApiClient _apiClient;
  final TripCache _cache;
  String _lastQuery = '';

  Future<Trip?> submit({
    required String query,
    String emergencyContactPhone = '',
    String routePreference = 'balanced',
  }) async {
    state = const TripRequestUiState.loading();
    _lastQuery = query;
    try {
      final map = await _apiClient.createTrip(
        query: query,
        emergencyContactPhone: emergencyContactPhone,
        routePreference: routePreference,
      );

      // §3.1: clarification is a 200 with a question, not an error.
      final clarify = map['clarification_needed'] as Map<String, dynamic>?;
      if (clarify != null) {
        final q = (clarify['question'] ?? 'Could you add more detail?')
            .toString();
        state = TripRequestUiState.clarify(q);
        return null;
      }

      if (map['trip_id'] == null) {
        state = const TripRequestUiState.error(
            'Unexpected response from server.');
        return null;
      }

      final trip = Trip.fromMap(map);
      _cache.save(trip);
      state = TripRequestUiState.success(trip);
      return trip;
    } catch (e) {
      state = TripRequestUiState.error(_messageFor(e));
      return null;
    }
  }

  /// Resubmit the original query with the user's answer appended.
  Future<Trip?> answerClarification(String answer, {String phone = ''}) {
    final merged = '$_lastQuery $answer'.trim();
    return submit(query: merged, emergencyContactPhone: phone);
  }

  void reset() => state = const TripRequestUiState.idle();

  String _messageFor(Object e) {
    final s = e.toString();
    if (s.contains('409')) {
      return 'Nothing under your budget. Try raising it a little.';
    }
    if (s.contains('422')) {
      return 'Could not understand that request. Try mentioning origin, destination and budget.';
    }
    if (s.contains('Connection refused') || s.contains('SocketException')) {
      return 'Cannot reach the Raahi backend. Is uvicorn running on port 8000?';
    }
    return 'Something went wrong. Please try again.';
  }
}

final raahiApiClientProvider =
    Provider<RaahiApiClient>((ref) => RaahiApiClient());

final tripRequestProvider = StateNotifierProvider<TripRequestNotifier,
    TripRequestUiState>((ref) {
  return TripRequestNotifier(
    apiClient: ref.watch(raahiApiClientProvider),
    cache: ref.watch(tripCacheProvider),
  );
});
