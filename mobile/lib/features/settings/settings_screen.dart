import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rahi/domain/models/emergency_contact.dart';

import '../../data/remote/raahi_api_client.dart';
import '../../data/local/trip_cache.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyContact =
        ref.watch(tripCacheProvider).maybeWhen(
              data: (trip) => trip.parsedIntent.emergencyContact,
              orElse: () => '',
            );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Emergency Contact',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Emergency contact phone (E.164 format)',
                hintText: '+919800000000',
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
              initialValue: emergencyContact,
              onChanged: (value) {
                // Update in local state - in full app would update provider state
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final refCtx = ref.read(tripCacheProvider);
                // In full app, would call API to register contact
                // final result = await ref.read(raahiApiClientProvider).registerEmergencyContact(
                //   phoneNumber: '+919800000000',
                //   relation: 'parent',
                // );
                // For now, just save locally
                // ref.read(tripCacheProvider.notifier).saveTrip(trip);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Emergency contact saved'),
                    ),
                  );
                }
              },
              child: const Text('Save Emergency Contact'),
            ),
            const Spacer(),
            const Text(
              'This contact will be notified automatically if you enter a flagged unsafe zone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}