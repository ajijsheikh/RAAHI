import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/models/trip.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/trip_event.dart';
import '../../domain/models/parsed_intent.dart';
import '../../domain/models/itinerary.dart';

class TripCache {
  late final Box _tripBox;
  late final Box _legBox;
  late final Box _eventBox;
  late final Box _intentBox;

  TripCache._init();

  static final TripCache _instance = TripCache._init();
  factory TripCache() => _instance;

  Future<void> init() async {
    if (_tripBox.isOpen && _legBox.isOpen && _eventBox.isOpen && _intentBox.isOpen) return;
    _tripBox = await Hive.openBox<Trip>('raahi_trip_cache');
    _legBox = await Hive.openBox<Leg>('raahi_leg_cache');
    _eventBox = await Hive.openBox<TripEvent>('raahi_event_cache');
    _intentBox = await Hive.openBox<ParsedIntent>('raahi_intent_cache');
  }

  Future<void> saveTrip(Trip trip) async {
    await init();
    await _tripBox.put('current_trip', trip);
    // Save itinerary legs
    await _legBox.clear();
    for (final leg in trip.itinerary.legs) {
      await _legBox.add(leg);
    }
    // Save parsed intent
    await _intentBox.put('stored_intent', trip.parsedIntent);
    // Save events
    await _eventBox.clear();
    for (final event in trip.events) {
      final hiveEvent = _toHiveEvent(event);
      await _eventBox.add(hiveEvent);
    }
  }

  Trip? getCurrentTrip() async {
    await init();
    final trip = _tripBox.get('current_trip');
    return trip;
  }

  ParsedIntent? getStoredIntent() async {
    await init();
    return _intentBox.get('stored_intent');
  }

  List<Leg> getCachedLegs() async {
    await init();
    return _legBox.values.toList();
  }

  List<TripEvent> getCachedEvents() async {
    await init();
    return _eventBox.values.toList();
  }

  Future<void> addEvent(TripEvent event) async {
    await init();
    final hiveEvent = _toHiveEvent(event);
    await _eventBox.add(hiveEvent);
  }

  Future<void> clear() async {
    await init();
    await _tripBox.clear();
    await _legBox.clear();
    await _eventBox.clear();
    await _intentBox.clear();
  }

  TripEvent _toHiveEvent(TripEvent event) {
    return TripEvent(
      eventType: event.eventType,
      triggerReason: event.triggerReason,
      legIndex: event.legIndex,
      oldLeg: event.oldLeg,
      newLeg: event.newLeg,
      message: event.message,
      twilioSid: event.twilioSid,
      createdAt: event.createdAt,
    );
  }
}