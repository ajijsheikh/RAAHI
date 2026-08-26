import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ride booking options for auto/rideshare legs (05_FEATURE_SPECS.md §3.3).
/// Estimates only — never presented as a live fare quote.
class RideOption {
  const RideOption({
    required this.provider,
    required this.estInr,
    this.deepLink,
    required this.webFallback,
  });

  final String provider;
  final int estInr;
  final String? deepLink; // native app scheme
  final String webFallback;

  Future<void> launch() async {
    final native = deepLink != null ? Uri.parse(deepLink!) : null;
    if (native != null && await canLaunchUrl(native)) {
      await launchUrl(native, mode: LaunchMode.externalApplication);
      return;
    }
    // Emulator has no cab apps → web fallback is the expected path on stage.
    await launchUrl(
      Uri.parse(webFallback),
      mode: LaunchMode.externalApplication,
    );
  }
}

// Demo estimates for Kolkata last-mile (PRD: Rapido primary, Uber fallback).
const _kolkataRides = <RideOption>[
  RideOption(
    provider: 'Rapido bike',
    estInr: 45,
    deepLink: 'rapido://open',
    webFallback: 'https://www.rapido.bike',
  ),
  RideOption(
    provider: 'Rapido auto',
    estInr: 60,
    deepLink: 'rapido://open',
    webFallback: 'https://www.rapido.bike',
  ),
  RideOption(
    provider: 'Uber auto',
    estInr: 85,
    deepLink: 'uber://',
    webFallback: 'https://m.uber.com',
  ),
  RideOption(
    provider: 'Uber cab',
    estInr: 140,
    deepLink: 'uber://',
    webFallback: 'https://m.uber.com',
  ),
];

Future<void> showBookRideSheet(BuildContext context) {
  final rides = [..._kolkataRides]..sort((a, b) => a.estInr.compareTo(b.estInr));

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Book a ride',
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                const Spacer(),
                Text('estimates',
                    style: Theme.of(sheetContext).textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final r in rides)
            ListTile(
              leading: const Icon(Icons.two_wheeler_outlined),
              title: Text(r.provider),
              trailing: FilledButton.tonal(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await r.launch();
                  } catch (_) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open ${r.provider}')),
                      );
                    }
                  }
                },
                child: Text('₹${r.estInr}'),
              ),
              subtitle: r.deepLink != null
                  ? const Text('opens in app if installed')
                  : null,
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
