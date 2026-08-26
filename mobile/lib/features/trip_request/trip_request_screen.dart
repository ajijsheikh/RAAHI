import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raahi/domain/models/parsed_intent.dart';
import 'package:raahi/domain/models/trip.dart';
import 'package:raahi/domain/models/itinerary.dart';

import '../../data/remote/raahi_api_client.dart';
import '../../data/local/trip_cache.dart';
import '../../main.dart';
import 'provider/trip_request_provider.dart';
import 'trip_request_screen.generated.dart';

class TripRequestScreen extends ConsumerWidget {
  const TripRequestScreen({super.key});

  static const _exampleQuery =
      'Howrah to Salt Lake Sector V, ₹200, need to reach by 10am';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tripRequestProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Trip'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Example query hint
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Example: $_exampleQuery',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Trip query text field
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Where are you heading?',
                  hintText: _exampleQuery,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    ref
                        .read(tripRequestProvider.notifier)
                        .submitQuery(query: value, emergencyContactPhone: '');
                  }
                },
              ),
              const SizedBox(height: 16),

              // Submit button
              ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () {
                        final query =
                            // ignore - simplified for demo
                            ''; // Would get from text field
                        // In a full widget, would capture the text field value
                        // For now, use example
                        ref
                            .read(tripRequestProvider.notifier)
                            .submitQuery(
                              query: _exampleQuery,
                              emergencyContactPhone: '+919800000000',
                            );
                      },
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Plan My Trip'),
              ),
              const SizedBox(height: 16),

              // State indicators
              _buildStateIndicator(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateIndicator(BuildContext context, TripRequestUiState state) {
    if (state.isIdle) return const SizedBox.shrink();
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      );
    }
    if (state.isError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          color: Colors.red[100],
          child: Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error: ${state.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (state.isSuccess) {
      // Navigate to active trip or show summary
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            // Navigate to active trip screen
            // context.go('/active-trip/${state.trip!.tripId}');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Trip planned! Navigate to active trip.'),
              ),
            );
          },
          child: const Text('View Active Trip'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}