import 'package:hive/hive.dart';

import '../../domain/models/trip.dart';
import '../../domain/models/leg.dart';
import '../../domain/models/trip_event.dart';
import '../../domain/models/parsed_intent.dart';
import '../../domain/models/itinerary.dart';

part 'trip_cache.g.dart';

@HiveType(typeId: 0)
class HiveLeg extends HiveObject {
  @HiveField(0)
  int legIndex;
  @HiveField(1)
  String mode;
  @HiveField(2)
  String from;
  @HiveField(3)
  String to;
  @HiveField(4)
  DateTime scheduledDeparture;
  @HiveField(5)
  int costInr;
  @HiveField(6)
  int travelTimeMinutes;

  HiveLeg({
    required this.legIndex,
    required this.mode,
    required this.from,
    required this.to,
    required this.scheduledDeparture,
    required this.costInr,
    required this.travelTimeMinutes,
  });

  factory HiveLeg.fromLeg(Leg leg) => HiveLeg(
        legIndex: leg.legIndex,
        mode: leg.mode,
        from: leg.from,
        to: leg.to,
        scheduledDeparture: leg.scheduledDeparture,
        costInr: leg.costInr,
        travelTimeMinutes: leg.travelTimeMinutes,
      );

  Leg toDomain() => Leg(
        legIndex: legIndex,
        mode: mode,
        from: from,
        to: to,
        scheduledDeparture: scheduledDeparture,
        costInr: costInr,
        travelTimeMinutes: travelTimeMinutes,
      );
}

@HiveType(typeId: 1)
class HiveTripEvent extends HiveObject {
  @HiveField(0)
  String eventType;
  @HiveField(1)
  String? triggerReason;
  @HiveField(2)
  int? legIndex;
  @HiveField(3)
  dynamic oldLeg;
  @HiveField(4)
  dynamic newLeg;
  @HiveField(5)
  String message;
  @HiveField(6)
  String? twilioSid;
  @HiveField(7)
  DateTime createdAt;

  HiveTripEvent({
    required this.eventType,
    this.triggerReason,
    this.legIndex,
    this.oldLeg,
    this.newLeg,
    required this.message,
    this.twilioSid,
    required this.createdAt,
  });

  factory HiveTripEvent.fromEvent(TripEvent event) => HiveTripEvent(
        eventType: event.eventType,
        triggerReason: event.triggerReason,
        legIndex: event.legIndex,
        oldLeg: event.oldLeg,
        newLeg: event.newLeg,
        message: event.message,
        twilioSid: event.twilioSid,
        createdAt: event.createdAt,
      );

  TripEvent toDomain() => TripEvent(
        eventType: eventType,
        triggerReason: triggerReason,
        legIndex: legIndex,
        oldLeg: oldLeg,
        newLeg: newLeg,
        message: message,
        twilioSid: twilioSid,
        createdAt: createdAt,
      );
}

@HiveType(typeId: 2)
class HiveParsedIntent extends HiveObject {
  @HiveField(0)
  String origin;
  @HiveField(1)
  String destination;
  @HiveField(2)
  int maxBudgetInr;
  @HiveField(3)
  DateTime? targetEta;
  @HiveField(4)
  String? emergencyContact;
  @HiveField(5)
  List<String>? amenitiesRequested;

  HiveParsedIntent({
    required this.origin,
    required this.destination,
    required this.maxBudgetInr,
    this.targetEta,
    this.emergencyContact,
    this.amenitiesRequested,
  });

  factory HiveParsedIntent.fromIntent(ParsedIntent intent) => HiveParsedIntent(
        origin: intent.origin,
        destination: intent.destination,
        maxBudgetInr: intent.maxBudgetInr,
        targetEta: intent.targetEta,
        emergencyContact: intent.emergencyContact,
        amenitiesRequested: intent.amenitiesRequested,
      );

  ParsedIntent toDomain() => ParsedIntent(
        origin: origin,
        destination: destination,
        maxBudgetInr: maxBudgetInr,
        targetEta: targetEta,
        emergencyContact: emergencyContact,
        amenitiesRequested: amenitiesRequested,
      );
}

@HiveType(typeId: 3)
class HiveItinerary extends HiveObject {
  @HiveField(0)
  int totalCostInr;
  @HiveField(1)
  int totalTimeMinutes;
  @HiveField(2)
  List<HiveLeg> legs;

  HiveItinerary({
    required this.totalCostInr,
    required this.totalTimeMinutes,
    required this.legs,
  });

  factory HiveItinerary.fromItinerary(Itinerary itinerary) => HiveItinerary(
        totalCostInr: itinerary.totalCostInr,
        totalTimeMinutes: itinerary.totalTimeMinutes,
        legs: itinerary.legs.map((leg) => HiveLeg.fromLeg(leg)).toList(),
      );

  Itinerary toDomain() => Itinerary(
        totalCostInr: totalCostInr,
        totalTimeMinutes: totalTimeMinutes,
        legs: legs.map((hiveLeg) => hiveLeg.toDomain()).toList(),
      );
}

@HiveType(typeId: 4)
class HiveTrip extends HiveObject {
  @HiveField(0)
  String tripId;
  @HiveField(1)
  String userId;
  @HiveField(2)
  String status;
  @HiveField(3)
  HiveParsedIntent parsedIntent;
  @HiveField(4)
  HiveItinerary itinerary;
  @HiveField(5)
  List<HiveTripEvent> events;
  @HiveField(6)
  DateTime createdAt;
  @HiveField(7)
  DateTime? completedAt;

  HiveTrip({
    required this.tripId,
    required this.userId,
    required this.status,
    required this.parsedIntent,
    required this.itinerary,
    required this.events,
    required this.createdAt,
    this.completedAt,
  });

  factory HiveTrip.fromTrip(Trip trip) => HiveTrip(
        tripId: trip.tripId,
        userId: trip.userId,
        status: trip.status,
        parsedIntent: HiveParsedIntent.fromIntent(trip.parsedIntent),
        itinerary: HiveItinerary.fromItinerary(trip.itinerary),
        events: trip.events.map((e) => HiveTripEvent.fromEvent(e)).toList(),
        createdAt: trip.createdAt,
        completedAt: trip.completedAt,
      );

  Trip toDomain() => Trip(
        tripId: tripId,
        userId: userId,
        status: status,
        parsedIntent: parsedIntent.toDomain(),
        itinerary: itinerary.toDomain(),
        events: events.map((e) => e.toDomain()).toList(),
        createdAt: createdAt,
        completedAt: completedAt,
      );
}

@HiveBox(name: 'raahi_trip_cache')
abstract class TripBox {
  HiveBox<HiveTrip> get activeTrip;
  HiveBox<HiveLeg> get legs;
  HiveBox<HiveTripEvent> get events;
  HiveBox<HiveParsedIntent> get parsedIntent;
}