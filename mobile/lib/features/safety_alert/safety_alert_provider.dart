import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Safety alert UI state. Full backend wiring (geofence event -> takeover)
/// lands with P3; this provider keeps the screen self-contained for now.
enum SafetyAlertStatus { idle, alerting, dismissed }

class SafetyAlertUiState {
  const SafetyAlertUiState({
    required this.status,
    this.zoneName,
    this.contactNotified = false,
  });

  final SafetyAlertStatus status;
  final String? zoneName;
  final bool contactNotified;
}
