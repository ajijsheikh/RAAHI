import 'package:flutter/material.dart';
import 'package:rahi/domain/models/trip_event.dart';

class SafetyAlertBanner extends StatelessWidget {
  final String zoneName;
  final String emergencyContact;
  final VoidCallback onDismiss;
  final VoidCallback onImsSafe;

  const SafetyAlertBanner({
    super.key,
    required this.zoneName,
    required this.emergencyContact,
    required this.onDismiss,
    required this.onImsSafe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(0xFFDC2626); // Red-600

    return Container(
      color: color.withOpacity(0.9),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Zone icon/indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          // Message text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flagged zone entered: $zoneName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Emergency contact notified: $emergencyContact',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // "I'm safe" button
          ElevatedButton(
            onPressed: onImsSafe,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: color,
              minimumSize: const Size(70, 30),
            ),
            child: const Text("I'm safe"),
          ),
        ],
      ),
    );
  }
}