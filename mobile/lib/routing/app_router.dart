import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/settings_screen.dart';
import '../features/trip_request/trip_request_screen.dart';
import '../features/active_trip/active_trip_screen.dart';

/// Riverpod provider so widgets ref.watch the router (hot-restart safe).
final appRouterProvider = Provider<GoRouter>((ref) => appRouter);

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'tripRequest',
      pageBuilder: (context, state) => const NoTransitionPage(child: TripRequestScreen()),
    ),
    GoRoute(
      path: '/trip/:id',
      name: 'activeTrip',
      pageBuilder: (context, state) => const NoTransitionPage(child: ActiveTripScreen()),
    ),
    GoRoute(
      path: '/trip/:id/alert',
      name: 'safetyAlert',
      pageBuilder: (context, state) => const NoTransitionPage(child: SafetyAlertPlaceholder()),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
    ),
  ],
);

/// Placeholder until B's full safety alert screen lands.
class SafetyAlertPlaceholder extends StatelessWidget {
  const SafetyAlertPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC62828),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 72),
              const SizedBox(height: 16),
              const Text(
                "You've entered a flagged area",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text("I'm safe"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
