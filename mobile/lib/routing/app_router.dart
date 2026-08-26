import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/active_trip/active_trip_screen.dart';
import '../features/active_trip/trip_summary_screen.dart';
import '../features/amenities/amenities_screen.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/trip_request/trip_request_screen.dart';

/// Riverpod provider so widgets ref.watch the router; rebuilds on auth change.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);

      // Demo mode / Supabase not configured: everything open.
      if (auth.isDemoMode || auth.status == AuthStatus.unknown) return null;

      final loggingIn = state.matchedLocation == '/login';
      if (!auth.isAuthenticated) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: '/',
        name: 'tripRequest',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: TripRequestScreen()),
      ),
      GoRoute(
        path: '/trip/:id',
        name: 'activeTrip',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: ActiveTripScreen()),
      ),
      GoRoute(
        path: '/trip/:id/alert',
        name: 'safetyAlert',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return NoTransitionPage(
            child: SafetyAlertPlaceholder(
              zoneName: extra?['zone_name'] as String? ?? 'flagged area',
              message: extra?['message'] as String?,
              contactNotified:
                  extra?['contact_notified'] as bool?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/trip/:id/amenities',
        name: 'amenities',
        pageBuilder: (context, state) => NoTransitionPage(
          child: AmenitiesScreen(tripId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/trip/:id/summary',
        name: 'tripSummary',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: TripSummaryScreen()),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SettingsScreen()),
      ),
    ],
  );
});

/// Safety alert takeover. Data comes from the real safety_alert SSE event
/// via go_router `extra`; demo AppBar entry falls back to defaults.
class SafetyAlertPlaceholder extends StatelessWidget {
  const SafetyAlertPlaceholder({
    super.key,
    this.zoneName = 'flagged area',
    this.message,
    this.contactNotified,
  });

  final String zoneName;
  final String? message;
  final bool? contactNotified; // null => status unknown, show neutral state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC62828),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 72),
              const SizedBox(height: 16),
              const Text(
                "You've entered a flagged area",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message ?? zoneName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                switch (contactNotified) {
                  true => 'Emergency contact notified',
                  false => 'Could not reach contact — retrying',
                  null => 'Contact notification in progress…',
                },
                style: TextStyle(
                  color: contactNotified == false ? Colors.amber : Colors.greenAccent,
                  fontSize: 13,
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
