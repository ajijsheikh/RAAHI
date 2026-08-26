class IntentParserDto {
  final String origin;
  final String destination;
  final int maxBudgetInr;
  final DateTime? targetEta;
  final String? emergencyContact;
  final List<String>? amenitiesRequested;

  IntentParserDto({
    required this.origin,
    required this.destination,
    required this.maxBudgetInr,
    this.targetEta,
    this.emergencyContact,
    this.amenitiesRequested,
  });

  Map<String, dynamic> toMap() => {
        'origin': origin,
        'destination': destination,
        'max_budget_inr': maxBudgetInr,
        if (targetEta != null) 'target_eta': targetEta!.toIso8601String(),
        'emergency_contact': emergencyContact,
        'amenities_requested': amenitiesRequested,
      };

  factory IntentParserDto.fromMap(Map<String, dynamic> m) => IntentParserDto(
        origin: m['origin'] ?? '',
        destination: m['destination'] ?? '',
        maxBudgetInr: m['max_budget_inr'] ?? 0,
        targetEta: m['target_eta'] != null ? DateTime.parse(m['target_eta']) : null,
        emergencyContact: m['emergency_contact'] as String?,
        amenitiesRequested: m['amenities_requested'] as List<String>?,
  );
}