import 'package:go_router/go_router.dart';
import 'features/trip_request/trip_request_screen.dart';
import 'features/active_trip/active_trip_screen.dart';
import 'features/settings/settings_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/trip-request',
  routes: [
    goRoute(
      path: '/trip-request',
      name: 'tripRequest',
      builder: (context, state) => const TripRequestScreen(),
    ),
    goRoute(
      path: '/active-trip/:tripId',
      name: 'activeTrip',
      builder: (context, state) => ActiveTripScreen(tripId: state.pathParameters['tripId']!),
    ),
    goRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

GoRoute goRoute({
  required String path,
  required String name,
  required Builder builder,
}) {
  return GoRoute(
    path: path,
    name: name,
    builder: builder,
  );
}