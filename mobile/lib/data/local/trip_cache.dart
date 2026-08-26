import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/trip.dart';

/// Minimal in-memory cache of the ACTIVE trip only (DATABASE.md client-cache
/// note). Hive/secure persistence lands with Person B's P2 phase — this keeps
/// the app runnable today without codegen.
class TripCache {
  Trip? _activeTrip;

  Trip? get activeTrip => _activeTrip;

  String? get emergencyContactPhone =>
      _activeTrip?.parsedIntent.emergencyContact;

  void save(Trip trip) => _activeTrip = trip;

  void clear() => _activeTrip = null;
}

final tripCacheProvider = Provider<TripCache>((ref) => TripCache());
