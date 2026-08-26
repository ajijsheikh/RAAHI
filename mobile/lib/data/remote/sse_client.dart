import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../domain/models/trip_event.dart';
import 'raahi_api_client.dart';

/// Hand-rolled SSE over Dio's streamed response (AGENTS.md §4 — no extra deps).
///
/// Non-negotiables from 02_PERSON_B P2.1:
///  * skip `heartbeat` events
///  * dedupe on event id (server replays history on reconnect)
///  * auto-reconnect with backoff (replay makes this safe)
///  * unknown type -> still yields; UI renders generic toast, never crashes
class SseClient {
  SseClient(this._dio, this._api);

  final Dio _dio;
  final RaahiApiClient _api;

  final Set<String> _seenEventIds = {};

  /// Connects to /trips/{id}/events and yields parsed TripEvents forever,
  /// reconnecting automatically on drop.
  Stream<TripEvent> connect(String tripId) async* {
    var backoff = const Duration(seconds: 2);
    while (true) {
      try {
        final response = await _dio.get<ResponseBody>(
          '${_api.baseUrl}/trips/$tripId/events',
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              'Accept': 'text/event-stream',
              'X-User-Id': await _api.userId,
            },
          ),
        );
        backoff = const Duration(seconds: 2); // reset after successful connect

        String buffer = '';
        String? eventName;
        String? eventData;

        await for (final chunk in response.data!.stream) {
          buffer += utf8.decode(chunk, allowMalformed: true);
          while (buffer.contains('\n')) {
            final idx = buffer.indexOf('\n');
            final line = buffer.substring(0, idx).trim();
            buffer = buffer.substring(idx + 1);

            if (line.isEmpty) {
              final ev = _dispatch(eventName, eventData);
              eventName = null;
              eventData = null;
              if (ev != null) yield ev;
            } else if (line.startsWith('event:')) {
              eventName = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              eventData = line.substring(5).trim();
            }
          }
        }
      } on DioException {
        // fallthrough to retry
      } catch (_) {
        // keep the stream alive regardless of parse errors
      }
      await Future<void>.delayed(backoff);
      backoff = backoff * 2 > const Duration(seconds: 30)
          ? const Duration(seconds: 30)
          : backoff * 2;
    }
  }

  TripEvent? _dispatch(String? name, String? data) {
    if (name == null || data == null || name == 'heartbeat') return null;

    Map<String, dynamic> payload = {};
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) payload = decoded;
    } catch (_) {
      payload = {'message': data}; // plain-text fallback
    }

    final eventId = payload['event_id']?.toString();
    if (eventId != null) {
      if (!_seenEventIds.add(eventId)) return null; // duplicate replay
    }

    return TripEvent.fromMap({
      'event_type': payload['type'] ?? name,
      'message': payload['message'] ?? '',
      'trigger_reason': payload['reason'] ?? payload['zone_name'],
      'leg_index': payload['leg_index'],
      'old_leg': payload['old_legs'] ?? payload['old_leg'],
      'new_leg': payload['new_legs'] ?? payload['new_leg'],
      'twilio_sid': payload['twilio_sid'],
      'created_at': payload['created_at'],
    });
  }
}
