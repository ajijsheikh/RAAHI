import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'provider/active_trip_provider.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  @override
  void initState() {
    super.initState();
    // Trip id comes from cache (set right after POST /trips).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeTripProvider.notifier).loadFromCache();
    });
  }

  void _onReroute(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F6E5C), // cAgent — autonomous action
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // React to live SSE events (02_PERSON_B P2.4/P3.2).
    ref.listen<ActiveTripUiState>(activeTripProvider, (prev, next) {
      final prevLen = prev?.events.length ?? 0;
      if (next.events.length > prevLen) {
        for (final e in next.events.sublist(prevLen)) {
          if (e.eventType == 'reroute') {
            _onReroute(
              e.message.isEmpty ? 'Route updated by agent' : e.message,
            );
          } else if (e.eventType == 'safety_alert') {
            final id = next.trip?.tripId ?? 'demo';
            context.go('/trip/$id/alert');
          }
        }
      }
    });

    final state = ref.watch(activeTripProvider);
    final scheme = Theme.of(context).colorScheme;
    final trip = state.trip;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your trip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded),
            tooltip: 'Safety alert (demo)',
            onPressed: () => context.go('/trip/demo/alert'),
          ),
        ],
      ),
      body: switch (state.status) {
        ActiveTripStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        ActiveTripStatus.error => Center(child: Text(state.errorMessage ?? '')),
        _ => trip == null
            ? const Center(child: Text('No active trip — plan one first.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Budget / ETA header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${trip.itinerary.totalCostInr}',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              Text(
                                '${trip.itinerary.totalTimeMinutes} min total',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          MonitoringDot(reroutes: state.rerouteCount),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Leg timeline
                  for (final leg in trip.itinerary.legs)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(_iconFor(leg.mode)),
                        title: Text('${leg.from} → ${leg.to}'),
                        subtitle: Text(
                          '${leg.travelTimeMinutes} min · dep '
                          '${DateFormat.Hm().format(leg.scheduledDeparture)}',
                        ),
                        trailing: Text('₹${leg.costInr}'),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Demo control strip — deliberately visible, labeled DEMO
                  Card(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: scheme.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('DEMO CONTROLS',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.schedule, size: 18),
                                  label: const Text('Delay 20 min'),
                                  onPressed: trip.tripId.isEmpty
                                      ? null
                                      : () => ref
                                          .read(activeTripProvider.notifier)
                                          .simulateDelay(trip.tripId),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.sos, size: 18),
                                  label: const Text('Zone entry'),
                                  onPressed: trip.tripId.isEmpty
                                      ? null
                                      : () => context.go('/trip/${trip.tripId}/alert'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Live events feed
                  if (state.events.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Live updates',
                        style: Theme.of(context).textTheme.titleMedium),
                    for (final e in state.events.reversed.take(10))
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.bolt, size: 18),
                        title: Text(e.message.isEmpty ? e.eventType : e.message),
                        subtitle: Text(e.eventType),
                      ),
                  ],
                ],
              ),
      },
    );
  }

  IconData _iconFor(String mode) => switch (mode) {
        'walk' => Icons.directions_walk,
        'bus' => Icons.directions_bus,
        'metro' => Icons.subway,
        'train' => Icons.train,
        'auto' => Icons.local_taxi,
        'rideshare' => Icons.hail,
        _ => Icons.route,
      };
}

/// Pulsing teal dot = "the agent is watching" (02_PERSON_B P2.3).
class MonitoringDot extends StatefulWidget {
  const MonitoringDot({super.key, this.reroutes = 0});

  final int reroutes;

  @override
  State<MonitoringDot> createState() => _MonitoringDotState();
}

class _MonitoringDotState extends State<MonitoringDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF0F6E5C), // cAgent
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.reroutes > 0
                ? 'Monitoring · ${widget.reroutes} reroute(s)'
                : 'Monitoring',
          ),
        ],
      ),
    );
  }
}
