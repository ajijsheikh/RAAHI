import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:raahi/data/remote/raahi_api_client.dart';

final raahiApiClientProvider =
    Provider((ref) => RaahiApiClient(
          dio: Dio(),
          secureStorage: const FlutterSecureStorage(),
        ));

// Fix: expose Dio instance separately for SSE client
final dioProvider = Provider<Dio>((ref) => Dio());

final sseClientProvider =
    Provider((ref) => SseClient(
          ref.watch(dioProvider),
          '/trips', // tripId will be set dynamically
        ));

// Simulated watcher state providers (for demo-controlled triggers)
final delayWatcherProvider =
    StateProvider.autoDispose((ref) => DelayWatcherState());

final safetyWatcherProvider =
    StateProvider.autoDispose((ref) => SafetyWatcherState());

final budgetWatcherProvider =
    StateProvider.autoDispose((ref) => BudgetWatcherState());

class DelayWatcherState {
  bool isMonitoring = false;
  int? activeLegIndex;
  int delayThresholdMinutes = 15;
}

class SafetyWatcherState {
  bool isMonitoring = false;
  bool insideZone = false;
  String? currentZoneName;
}

class BudgetWatcherState {
  bool isMonitoring = false;
  int runningSpend = 0;
  int maxBudget = 200;
}