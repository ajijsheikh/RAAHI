import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raahi/domain/models/trip_event.dart';

enum SafetyAlertStatus { idle, alert, dismissed }

class SafetyAlertNotifier extends StateNotifier<SafetyAlertUiState> {
  SafetyAlertNotifier() : super(const SafetyAlertUiState.idle());

  void showAlert({
    required String zoneName,
    required String contactName,
    required double lat,
    required double lng,
  }) {
    state = SafetyAlertUiState.alert(
      zoneName: zoneName,
      contactName: contactName,
      lat: lat,
      lng: lng,
    );
  }

  void dismissAlert() {
    state = const SafetyAlertUiState.idle();
  }

  void markContactNotified() {
    state = SafetyAlertUiState.dismissed(
      contactNotified: true,
    );
  }
}

final safetyAlertProvider =
    StateNotifierProvider<SafetyAlertNotifier, SafetyAlertUiState>((ref) {
  return SafetyAlertNotifier();
});

class SafetyAlertUiState {
  final SafetyAlertStatus status;
  final String? zoneName;
  final String? contactName;
  final double? lat;
  final double? lng;
  final bool contactNotified;

  SafetyAlertUiState._({
    required this.status,
    this.zoneName,
    this.contactName,
    this.lat,
    this.lng,
    this.contactNotified = false,
  });

  factory SafetyAlertUiState.idle() => const SafetyAlertUiState._(
        status: SafetyAlertStatus.idle,
        contactNotified: false,
      );

  factory SafetyAlertUiState.alert({
    required String zoneName,
    required String contactName,
    required double lat,
    required double lng,
  }) => SafetyAlertUiState._(
        status: SafetyAlertStatus.alert,
        zoneName: zoneName,
        contactName: contactName,
        lat: lat,
        lng: lng,
        contactNotified: false,
      );

  factory SafetyAlertUiState.dismissed({required bool contactNotified}) =>
      SafetyAlertUiState._(
        status: SafetyAlertStatus.dismissed,
        contactNotified: contactNotified,
      );
}