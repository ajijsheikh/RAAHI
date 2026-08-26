import 'package:raahi/data/remote/raahi_api_client.dart';
import 'package:raahi/domain/models/trip.dart';

class TripRepository {
  final RaahiApiClient _apiClient;

  TripRepository(this._apiClient);

  Future<Trip> createTrip({
    required String query,
    required String emergencyContactPhone,
  }) async {
    final response = await _apiClient.createTrip(
      query: query,
      emergencyContactPhone: emergencyContactPhone,
    );
    return response;
  }

  Future<Trip> getTrip(String tripId) async {
    final response = await _apiClient.getTrip(tripId);
    return response;
  }

  Future<void> simulateDelay({
    required String tripId,
    required int legIndex,
    required int delayMinutes,
  }) async {
    await _apiClient.simulateDelay(
      tripId: tripId,
      legIndex: legIndex,
      delayMinutes: delayMinutes,
    );
  }

  Future<void> simulateSafetyTrigger({
    required String tripId,
    required String zoneId,
  }) async {
    await _apiClient.simulateSafetyTrigger(
      tripId: tripId,
      zoneId: zoneId,
    );
  }
}