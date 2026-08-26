import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import '../../main.dart';
import '../../domain/models/trip_event.dart';
import 'safety_alert_provider.dart';

class SafetyAlertScreen extends ConsumerWidget {
  const SafetyAlertScreen({super.key, required this.zoneName, required this.contactName, required this.lat, required this.lng});

  final String zoneName;
  final String contactName;
  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(safetyAlertProvider);

    return Scaffold(
      body: Container(
        color: Colors.black87,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amberAccent,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'You\'ve entered a flagged area',
                    style: GoogleFonts.openSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    zoneName,
                    style: GoogleFonts.openSans(
                      fontSize: 16,
                      color: Colors.amberAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildContactChip(ref, contactName),
                      const SizedBox(width: 16),
                      _buildStatusIcon(state.contactNotified),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Live location: $lat, $lng',
                    style: GoogleFonts.openSans(
                      fontSize: 14,
                      color: Colors.grey[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () async {
                      HapticFeedback.heavyImpact();
                      final uri = Uri.parse('tel:$contactName');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Call Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      ref.read(safetyAlertProvider.notifier).dismissAlert();
                      Navigator.pop(context);
                    },
                    child: const Text('I\'m Safe'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      ref.read(safetyAlertProvider.notifier).markContactNotified();
                      Navigator.pop(context);
                    },
                    child: const Text('Open Map'),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactChip(WidgetRef ref, String contactName) {
    final uiState = ref.watch(safetyAlertProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            uiState.contactNotified ? Icons.check_circle : Icons.person,
            color: uiState.contactNotified ? Colors.green : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            contactName,
            style: GoogleFonts.openSans(
              color: uiState.contactNotified ? Colors.green : Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool notified) {
    return Icon(
      notified ? Icons.check_circle : Icons.info_outline,
      color: notified ? Colors.green : Colors.white70,
      size: 24,
    );
  }
}