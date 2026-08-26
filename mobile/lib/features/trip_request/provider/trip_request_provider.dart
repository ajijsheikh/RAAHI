import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raahi/data/remote/raahi_api_client.dart';
import 'package:raahi/domain/models/trip.dart';
import 'package:raahi/domain/models/parsed_intent.dart';
import 'package:raiah/domain/models/itinerary.dart';

import '../../data/local/trip_cache.dart';
import 'trip_request_screen.dart';

final tripRequestProvider =
    StateNotifierProvider<TripRequestNotifier, TripRequestUiState>((ref) {
  return TripRequestNotifier(
    apiClient: ref.watch(raahiApiClientProvider),
    cache: ref.watch(tripCacheProvider),
  );
});

class TripRequestNotifier extends StateNotifier<TripRequestUiState> {
  final RaahiApiClient _apiClient;
  final TripCache _cache;

  TripRequestNotifier({
    required RaahiApiClient apiClient,
    required TripCache cache,
  })  : _apiClient = apiClient,
        _cache = cache,
        super(const TripRequestUiState.idle());

  Future<void> submitQuery({
    required String query,
    required String emergencyContactPhone,
  }) async {
    state = const TripRequestUiState.loading();
    try {
      final response = await _apiClient.createTrip(
        query: query,
        emergencyContactPhone: emergencyContactPhone,
      );
      state = TripRequestUiState.success(response);
      // Cache the trip
      await _cache.saveTrip(response);
    } on Exception catch (e) {
      state = TripRequestUiState.error(_mapExceptionToMessage(e));
    }
  }

  Future<void> clarifyField({
    required String field,
    required String value,
  }) async {
    // Submit the clarification value back to the backend
    state = const TripRequestUiState.loading();
    try {
      final response = await _apiClient.createTrip(
        query: value,
        emergencyContactPhone: state.maybeWhen(
          data: (trip) => trip.parsedIntent.emergencyContact ?? '',
          orElse: () => '',
        ),
      );
      state = TripRequestUiState.success(response);
      await _cache.saveTrip(response);
    } on Exception catch (e) {
      state = TripRequestUiState.error(_mapExceptionToMessage(e));
    }
  }

  String _mapExceptionToMessage(Exception e) {
    if (e.toString().contains('422')) return 'Could not parse trip request. Please check the fields.';
    if (e.toString().contains('409')) return 'No route under budget. Try adjusting your budget.';
    return 'An error occurred. Please try again.';
  }
}

enum TripRequestStatus { idle, loading, success, error }

class TripRequestUiState {
  final TripRequestStatus status;
  final Trip? trip;
  final String? errorMessage;
  final String? clarificationField;
  final String? clarificationQuestion;

  TripRequestUiState._({
    required this.status,
    this.trip,
    this.errorMessage,
    this.clarificationField,
    this.clarificationQuestion,
  });

  factory TripRequestUiState.idle() => const TripRequestUiState._(
        status: TripRequestStatus.idle,
        trip: null,
        errorMessage: null,
        clarificationField: null,
        clarificationQuestion: null,
      );

  factory TripRequestUiState.loading() => const TripRequestUiState._(
        status: TripRequestStatus.loading,
        trip: null,
        errorMessage: null,
        clarificationField: null,
        clarificationQuestion: null,
      );

  factory TripRequestUiState.success(TripResponse trip) => const TripRequestUiState._(
        status: TripRequestStatus.success,
        trip: null,
        errorMessage: null,
        clarificationField: null,
        clarificationQuestion: null,
      );

  factory TripRequestUiState.error(String message) => const TripRequestUiState._(
        status: TripRequestStatus.error,
        trip: null,
        errorMessage: message,
        clarificationField: null,
        clarificationQuestion: null,
      );

  bool get isIdle => status == TripRequestStatus.idle;
  bool get isLoading => status == TripRequestStatus.loading;
  bool get isSuccess => status == TripRequestStatus.success;
  bool get isError => status == TripRequestStatus.error;

  String? get error => errorMessage;
}