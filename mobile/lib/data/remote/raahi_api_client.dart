import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/trip.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/trip_event.dart';
import '../../domain/models/parsed_intent.dart';
import '../../domain/models/itinerary.dart';
import '../dto/intent_parser_dto.dart';

class RaahiApiClient {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  RaahiApiClient({Dio? dio, FlutterSecureStorage? secureStorage})
      : _dio = dio ?? Dio(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<String> get _userId async {
    final id = await _secureStorage.read(key: 'user_id');
    if (id != null) return id;
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    await _secureStorage.write(key: 'user_id', value: newId);
    return newId;
  }

  Future<void> _init() async {
    final baseUrl = _getBaseUrl();
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers['X-User-Id'] = await _userId;
  }

  String _getBaseUrl() {
    // In production, this would read from env or config
    // For demo: check if we're on Android emulator (10.0.2.2) or iOS simulator (localhost)
    // The base URL is set via --dart-define API_BASE_URL=... at build time
    final dartDefine = Platform.environment['API_BASE_URL'];
    if (dartDefine != null && dartDefine.isNotEmpty) return dartDefine;
    // fallback defaults
    return _platformSpecificBaseUrl();
  }

  String _platformSpecificBaseUrl() {
    // This is handled at build time via --dart-define
    // If not set, default to localhost (for iOS simulator) or 10.0.2.2 (for Android emulator)
    return 'http://localhost:8000/api/v1';
  }

  Future<T> _request<T>(
    String method,
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic> queryParameters?,
  }) async {
    await _init();
    try {
      Response response;
      if (method == 'GET') {
        response = await _dio.get<T>(
          path,
          queryParameters: queryParameters,
        );
      } else if (method == 'POST') {
        response = await _dio.post<T>(
          path,
          data: json.encode(data),
          options: Options(
            contentType: ContentType.json,
            headers: {'Content-Type': 'application/json'},
          ),
        );
      } else if (method == 'PUT') {
        response = await _dio.put<T>(
          path,
          data: json.encode(data),
          options: Options(
            contentType: ContentType.json,
            headers: {'Content-Type': 'application/json'},
          ),
        );
      } else {
        throw ArgumentError('Unsupported HTTP method: $method');
      }
      return response.data as T;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    // Could add centralized error mapping here
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        // Timeout error - user-friendly message
        break;
      case DioExceptionType.connectionError:
        // Connection error
        break;
      default:
        break;
    }
  }

  // API Endpoint 1: POST /trips - Create trip from natural language
  Future<TripResponse> createTrip({
    required String query,
    required String emergencyContactPhone,
  }) async {
    final response = await _request<Map<String, dynamic>>(
      'POST',
      '/trips',
      data: {
        'query': query,
        'emergency_contact_phone': emergencyContactPhone,
      },
    );
    return TripResponse.fromMap(response);
  }

  // API Endpoint 2: GET /trips/{trip_id} - Fetch current trip
  Future<Trip> getTrip(String tripId) async {
    final response = await _request<Map<String, dynamic>>(
      'GET',
      '/trips/$tripId',
    );
    return Trip.fromMap(response);
  }

  // API Endpoint 3: GET /trips/{trip_id}/events - SSE stream
  // Exposed as a method that returns a stream; the SSE client handles the actual streaming
  Stream<TripEvent> getTripEvents(String tripId) {
    // This will be handled by the SSE client
    // For now, return an empty stream; the SSE client will override
    return _emptyEventStream();
  }

  // API Endpoint 6: GET /amenities - Standalone amenity search
  Future<AmenityListResponse> searchAmenities({
    required double lat,
    required double lng,
    double radiusKm = 2.0,
    String? category,
  }) async {
    final response = await _request<Map<String, dynamic>>(
      'GET',
      '/amenities',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        if (category != null) 'query': category,
      },
    );
    return AmenityListResponse.fromMap(response);
  }

  // API Endpoint 7: POST /emergency-contacts - Register emergency contact
  Future<EmergencyContactResponse> registerEmergencyContact({
    required String phoneNumber,
    String? relation,
  }) async {
    final response = await _request<Map<String, dynamic>>(
      'POST',
      '/emergency-contacts',
      data: {
        'phone_number': phoneNumber,
        'relation': relation,
      },
    );
    return EmergencyContactResponse.fromMap(response);
  }

  // Demo-only: simulate delay trigger
  Future<void> simulateDelay({
    required String tripId,
    required int legIndex,
    required int delayMinutes,
  }) async {
    await _request<void>(
      'POST',
      '/trips/$tripId/simulate-delay',
      data: {
        'leg_index': legIndex,
        'delay_minutes': delayMinutes,
      },
    );
  }

  // Demo-only: simulate safety trigger
  Future<void> simulateSafetyTrigger({
    required String tripId,
    required String zoneId,
  }) async {
    await _request<void>(
      'POST',
      '/trips/$tripId/simulate-safety-trigger',
      data: {
        'zone_id': zoneId,
      },
    );
  }

  Stream<TripEvent> _emptyEventStream() => const Stream.empty();
}

class TripResponse {
  final String tripId;
  final String status;
  final ParsedIntent parsedIntent;
  final Itinerary itinerary;
  final Map<String, List<AmenityDto>> amenities;

  TripResponse({
    required this.tripId,
    required this.status,
    required this.parsedIntent,
    required this.itinerary,
    required this.amenities,
  });

  factory TripResponse.fromMap(Map<String, dynamic> map) {
    final amenitiesMap = (map['amenities'] as Map<String, dynamic>?)
        ?.map((key, value) => MapEntry(
              key,
              (value as List<dynamic>)
                  .map((item) => AmenityDto.fromMap(item as Map<String, dynamic>))
                  .toList(),
            )) ??
        {};

    return TripResponse(
      tripId: map['trip_id'] ?? '',
      status: map['status'] ?? '',
      parsedIntent: ParsedIntent.fromMap(map['parsed_intent'] as Map<String, dynamic>),
      itinerary: Itinerary.fromMap(map['itinerary'] as Map<String, dynamic>),
      amenities: amenitiesMap,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trip_id': tripId,
      'status': status,
      'parsed_intent': parsedIntent.toMap(),
      'itinerary': itinerary.toMap(),
      'amenities': amenities,
    };
  }
}

class AmenityDto {
  final String name;
  final String category;
  final int priceInr;
  final double distanceKm;
  final String? description;
  final String source;

  AmenityDto({
    required this.name,
    required this.category,
    required this.priceInr,
    required this.distanceKm,
    this.description,
    this.source = 'demo_curated',
  }

  factory AmenityDto.fromMap(Map<String, dynamic> map) {
    return AmenityDto(
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      priceInr: map['price_inr'] ?? 0,
      distanceKm: (map['distance_km'] ?? 0.0).toDouble(),
      description: map['description'] as String?,
      source: map['source'] ?? 'demo_curated',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'price_inr': priceInr,
      'distance_km': distanceKm,
      'description': description,
      'source': source,
    };
  }
}

class AmenityListResponse {
  final List<AmenityDto> results;

  AmenityListResponse({required this.results});

  factory AmenityListResponse.fromMap(Map<String, dynamic> map) {
    final resultsList = map['results'] as List<dynamic>?;
    final results = resultsList
        ?.map((item) => AmenityDto.fromMap(item as Map<String, dynamic>))
        .toList() ??
        [];
    return AmenityListResponse(results: results);
  }

  Map<String, dynamic> toMap() {
    return {'results': results.map((r) => r.toMap()).toList()};
  }
}

class EmergencyContactResponse {
  final String id;
  final String phoneNumber;
  final String? relation;
  final DateTime createdAt;

  EmergencyContactResponse({
    required this.id,
    required this.phoneNumber,
    this.relation,
    required this.createdAt,
  });

  factory EmergencyContactResponse.fromMap(Map<String, dynamic> map) {
    return EmergencyContactResponse(
      id: map['id'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      relation: map['relation'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'relation': relation,
      'created_at': createdAt.toIso8601String(),
    };
  }
}