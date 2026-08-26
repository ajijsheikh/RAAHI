class Leg {
  final int legIndex;
  final String mode;
  final String from;
  final String to;
  final DateTime scheduledDeparture;
  final int costInr;
  final int travelTimeMinutes;

  Leg({
    required this.legIndex,
    required this.mode,
    required this.from,
    required this.to,
    required this.scheduledDeparture,
    required this.costInr,
    required this.travelTimeMinutes,
  });

  factory Leg.fromMap(Map<String, dynamic> map) {
    return Leg(
      legIndex: map['leg_index'],
      mode: map['mode'],
      from: map['from'],
      to: map['to'],
      scheduledDeparture: DateTime.parse(map['scheduled_departure']),
      costInr: map['cost_inr'],
      travelTimeMinutes: map['travel_time_minutes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leg_index': legIndex,
      'mode': mode,
      'from': from,
      'to': to,
      'scheduled_departure': scheduledDeparture.toIso8601String(),
      'cost_inr': costInr,
      'travel_time_minutes': travelTimeMinutes,
    };
  }
}

class TripEvent {
  final String eventType;
  final String? triggerReason;
  final int? legIndex;
  final dynamic oldLeg;
  final dynamic newLeg;
  final String message;
  final String? twilioSid;
  final DateTime createdAt;

  TripEvent({
    required this.eventType,
    this.triggerReason,
    this.legIndex,
    this.oldLeg,
    this.newLeg,
    required this.message,
    this.twilioSid,
    required this.createdAt,
  });

  factory TripEvent.fromMap(Map<String, dynamic> map) {
    return TripEvent(
      eventType: map['event_type'],
      triggerReason: map['trigger_reason'],
      legIndex: map['leg_index'] != null ? int.parse(map['leg_index'].toString()) : null,
      oldLeg: map['old_leg'],
      newLeg: map['new_leg'],
      message: map['message'],
      twilioSid: map['twilio_sid'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_type': eventType,
      'trigger_reason': triggerReason,
      'leg_index': legIndex,
      'old_leg': oldLeg,
      'new_leg': newLeg,
      'message': message,
      'twilio_sid': twilioSid,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Itinerary {
  final int totalCostInr;
  final int totalTimeMinutes;
  final List<Leg> legs;

  Itinerary({
    required this.totalCostInr,
    required this.totalTimeMinutes,
    required this.legs,
  });

  factory Itinerary.fromMap(Map<String, dynamic> map) {
    final legsList = map['legs'] as List?;
    final legs = legsList
        ?.map((leg) => Leg.fromMap(leg as Map<String, dynamic>))
        .toList() ??
        [];
    return Itinerary(
      totalCostInr: map['total_cost_inr'] ?? 0,
      totalTimeMinutes: map['total_time_minutes'] ?? 0,
      legs: legs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_cost_inr': totalCostInr,
      'total_time_minutes': totalTimeMinutes,
      'legs': legs.map((leg) => leg.toMap()).toList(),
    };
  }
}

class ParsedIntent {
  final String origin;
  final String destination;
  final int maxBudgetInr;
  final DateTime? targetEta;
  final String? emergencyContact;
  final List<String>? amenitiesRequested;

  ParsedIntent({
    required this.origin,
    required this.destination,
    required this.maxBudgetInr,
    this.targetEta,
    this.emergencyContact,
    this.amenitiesRequested,
  });

  factory ParsedIntent.fromMap(Map<String, dynamic> map) {
    return ParsedIntent(
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      maxBudgetInr: map['max_budget_inr'] ?? 0,
      targetEta: map['target_eta'] != null ? DateTime.parse(map['target_eta']) : null,
      emergencyContact: map['emergency_contact'] as String?,
      amenitiesRequested: map['amenities_requested'] as List<String>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'origin': origin,
      'destination': destination,
      'max_budget_inr': maxBudgetInr,
      'target_eta': targetEta?.toIso8601String(),
      'emergency_contact': emergencyContact,
      'amenities_requested': amenitiesRequested,
    };
  }
}

class Trip {
  final String tripId;
  final String userId;
  final String status;
  final ParsedIntent parsedIntent;
  final Itinerary itinerary;
  final List<TripEvent> events;
  final DateTime createdAt;
  final DateTime? completedAt;

  Trip({
    required this.tripId,
    required this.userId,
    required this.status,
    required this.parsedIntent,
    required this.itinerary,
    required this.events,
    required this.createdAt,
    this.completedAt,
  });

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      tripId: map['trip_id'] ?? '',
      userId: map['user_id'] ?? '',
      status: map['status'] ?? 'planning',
      parsedIntent: ParsedIntent.fromMap(map['parsed_intent'] as Map<String, dynamic>),
      itinerary: Itinerary.fromMap(map['itinerary'] as Map<String, dynamic>),
      events: (map['events'] as List?)
          ?.map((event) => TripEvent.fromMap(event as Map<String, dynamic>))
          .toList() ??
          [],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trip_id': tripId,
      'user_id': userId,
      'status': status,
      'parsed_intent': parsedIntent.toMap(),
      'itinerary': itinerary.toMap(),
      'events': events.map((e) => e.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}