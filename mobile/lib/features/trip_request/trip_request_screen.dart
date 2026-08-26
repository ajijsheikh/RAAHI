import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'provider/trip_request_provider.dart';

class TripRequestScreen extends ConsumerStatefulWidget {
  const TripRequestScreen({super.key});

  @override
  ConsumerState<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends ConsumerState<TripRequestScreen> {
  late final TextEditingController _query;
  final _contact = TextEditingController();

  static const _defaultQuery =
      'Howrah se Salt Lake Sector V, ₹200, 10 baje tak';

  static const _preferences = ['balanced', 'fastest', 'cheapest', 'safest'];
  String _selectedPreference = 'balanced';

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: _defaultQuery);
  }

  @override
  void dispose() {
    _query.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _plan() async {
    final trip = await ref.read(tripRequestProvider.notifier).submit(
          query: _query.text.trim(),
          emergencyContactPhone: _contact.text.trim(),
          routePreference: _selectedPreference,
        );
    if (trip != null && mounted) {
      context.go('/trip/${trip.tripId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripRequestProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raahi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _query,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Where are you heading?',
                hintText: _defaultQuery,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Route preference chips (demo beat #4)
            Wrap(
              spacing: 8,
              children: [
                for (final p in _preferences)
                  ChoiceChip(
                    label: Text(_labelFor(p)),
                    selected: _selectedPreference == p,
                    onSelected: (_) =>
                        setState(() => _selectedPreference = p),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _contact,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Emergency contact (optional)',
                hintText: '+919800000000',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Voice input — decision D1: disabled, not deleted
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Voice — coming soon',
                onPressed: null,
                icon: Icon(Icons.mic_none, color: scheme.outline),
              ),
            ),
            const SizedBox(height: 8),

            FilledButton(
              onPressed: state.isLoading ? null : _plan,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              child: state.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Plan my trip'),
            ),

            if (state.status.name == 'error' && state.errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(state.errorMessage!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _labelFor(String p) => switch (p) {
        'balanced' => 'Balanced',
        'fastest' => 'Fastest',
        'cheapest' => 'Cheapest',
        'safest' => 'Safest',
        _ => p,
      };
}
