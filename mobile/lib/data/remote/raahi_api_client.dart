import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/trip.dart';

class RaahiApiClient {
  RaahiApiClient({Dio? dio, FlutterSecureStorage? secureStorage})
      : _dio = dio ?? Dio(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  String get baseUrl => _baseUrl;

  Future<String> get userId async {
    final existing = await _secureStorage.read(key: 'user_id');
    if (existing != null) return existing;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _secureStorage.write(key: 'user_id', value: id);
    return id;
  }

  Future<Options> _authed({ResponseType? responseType}) async {
    return Options(
      responseType: responseType,
      headers: {'X-User-Id': await userId},
    );
  }

  // POST /trips — natural-language trip request
  Future<Trip> createTrip({
    required String query,
    String? emergencyContactPhone,
    String routePreference = 'balanced',
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/trips',
      data: jsonEncode({
        'query': query,
        if (emergencyContactPhone != null && emergencyContactPhone.isNotEmpty)
          'emergency_contact_phone': emergencyContactPhone,
        'route_preference': routePreference,
      }),
      options: await _authed(),
    );
    return Trip.fromMap(res.data!);
  }

  // GET /trips/{id}
  Future<Trip> getTrip(String tripId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/trips/$tripId',
      options: await _authed(),
    );
    return Trip.fromMap(res.data!);
  }

  // GET /trips/{id}/events — SSE stream (parsed in SseClient)
  Future<void> simulateDelay({
    required String tripId,
    required int legIndex,
    required int delayMinutes,
  }) =>
      _fireAndForget('/trips/$tripId/simulate-delay', {
        'leg_index': legIndex,
        'delay_minutes': delayMinutes,
      });

  Future<void> simulateZoneEntry({
    required String tripId,
    required String zoneName,
  }) =>
      _fireAndForget('/trips/$tripId/simulate/zone-entry', {
        'zone_name': zoneName,
      });

  Future<void> sendSos(String tripId) =>
      _fireAndForget('/trips/$tripId/sos', {});

  // GET /amenities
  Future<List<Map<String, dynamic>>> searchAmenities({
    required double lat,
    required double lng,
    double radiusKm = 2.0,
    String? kind,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/amenities',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        if (kind != null) 'kind': kind,
      },
      options: await _authed(),
    );
    final results = res.data?['results'] as List<dynamic>? ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  // GET /irctc/pnr/{pnr}
  Future<Map<String, dynamic>> verifyPnr(String pnr) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/irctc/pnr/$pnr',
      options: await _authed(),
    );
    return res.data ?? {};
  }

  Future<void> _fireAndForget(String path, Map<String, dynamic> body) async {
    try {
      await _dio.post('$_baseUrl$path', data: jsonEncode(body), options: await _authed());
    } on DioException {
      // demo triggers are fire-and-forget; real change arrives via SSE
    }
  }
}
