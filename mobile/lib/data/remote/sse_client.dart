import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/models/trip_event.dart';

class SseClient {
  final Dio _dio;
  final String _tripId;

  SseClient(this._dio, this._tripId);

  /// Open SSE connection and return a stream of [TripEvent]
  /// The caller is responsible for opening/closing the Dio stream
  Stream<TripEvent> eventsStream() async* {
    final response = await _dio.fetch(
      '/trips/$_tripId/events',
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data as Stream<List<int>>;
    final encoder = utf8.decoder;
    String buffer = '';
    String? currentEventType;
    String? currentData;

    await for (final chunk in stream) {
      final text = encoder.convert(chunk);
      for (final line in text.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          // End of event - yield if we have a complete event
          if (currentEventType != null && currentData != null) {
            final eventType = currentEventType!;
            final data = currentData!;
            currentEventType = null;
            currentData = null;

            final event = _parseSseEvent(eventType, data);
            if (event != null) yield event;
          }
        } else if (trimmed.startsWith('event:')) {
          currentEventType = trimmed.substring(6).trim();
        } else if (trimmed.startsWith('data:')) {
          currentData = trimmed.substring(5).trim();
        }
      }
    }

    // Handle last event if stream ends without trailing newline
    if (currentEventType != null && currentData != null) {
      yield _parseSseEvent(currentEventType!, currentData!);
    }
  }

  TripEvent _parseSseEvent(String eventType, String data) {
    final map = <String, dynamic>{};
    for (final part in data.split(',')) {
      final equalsIdx = part.indexOf('=');
      if (equalsIdx > 0) {
        final key = part.substring(0, equalsIdx).trim();
        final value = part.substring(equalsIdx + 1).trim();
        map[key] = value;
      }
    }

    return TripEvent(
      eventType: eventType,
      triggerReason: map['trigger_reason'] as String?,
      legIndex: _parseLegIndex(map['leg_index']),
      oldLeg: _parseOldLeg(map['old_leg']),
      newLeg: _parseNewLeg(map['new_leg']),
      message: map['message'] as String?,
      twilioSid: map['twilio_sid'] as String?,
    );
  }

  int? _parseLegIndex(dynamic value) {
    if (value == null) return null;
    if (int.tryParse(value.toString()) != null) {
      return int.parse(value.toString());
    }
    return null;
  }

  dynamic _parseLegJson(dynamic value) {
    if (value == null) return null;
    if (value is! String) return value;
    try {
      return json.decode(value);
    } catch (_) {
      return value;
    }
  }

  dynamic _parseOldLeg(dynamic value) => _parseLegJson(value);
  dynamic _parseNewLeg(dynamic value) => _parseLegJson(value);
}