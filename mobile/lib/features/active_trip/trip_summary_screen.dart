import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'provider/active_trip_provider.dart';

/// Trip-complete summary (02_PERSON_B P4.3): cost, duration, reroutes,
/// alerts — the "what did the agent do" recap.
class TripSummaryScreen extends ConsumerWidget {
  const TripSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeTripProvider);
    final trip = state.trip;
    final scheme = Theme.of(context).colorScheme;

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip summary')),
        body: const Center(child: Text('No trip to summarise.')),
      );
    }

    final alertCount =
        state.events.where((e) => e.eventType == 'safety_alert').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip complete'),
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('₹${trip.itinerary.totalCostInr}',
                    style: Theme.of(context).textTheme.displaySmall),
                const Text('total spent'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _row(context, Icons.timer_outlined,
              '${trip.itinerary.totalTimeMinutes} min travel time'),
          _row(context, Icons.alt_route, '${state.rerouteCount} agent reroute(s)'),
          _row(context, Icons.warning_amber_outlined,
              '$alertCount safety alert(s)'),
          _row(context, Icons.route,
              '${trip.itinerary.legs.length} legs · ${trip.parsedIntent.destination}'),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Plan another trip'),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      dense: true,
    );
  }
}
