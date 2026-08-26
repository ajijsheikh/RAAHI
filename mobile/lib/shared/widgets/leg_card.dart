import 'package:flutter/material.dart';
import 'package:raahi/domain/models/leg.dart';

class LegCard extends StatelessWidget {
  final Leg leg;
  final bool isActive;
  final bool isCompleted;

  const LegCard({
    super.key,
    required this.leg,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = isActive && !isCompleted;
    final color = isCurrent
        ? theme.colorScheme.secondary
        : (isCompleted
            ? theme.colorScheme.outline
            : theme.colorScheme.onSurface);

    return Card(
      color: theme.colorScheme.surface,
      elevation: isCurrent ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Mode icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isCurrent ? color.withOpacity(0.1) : null,
                borderRadius: BorderRadius.circular(4),
                border: isCurrent
                    ? Border.all(color: color, width: 2)
                    : null,
              ),
              child: Icon(
                _modeIcon(leg.mode),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Leg details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${leg.from} → ${leg.to}',
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${leg.costInr} INR ',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '| ${leg.travelTimeMinutes} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isCurrent
                    ? color
                    : (isCompleted
                        ? theme.colorScheme.outline
                        : theme.colorScheme.secondary),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _modeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'walk':
        return Icons.directions_walk;
      case 'bus':
        return Icons.directions_bus;
      case 'metro':
        return Icons.train;
      case 'train':
        return Icons.train;
      case 'auto':
        return Icons.local_taxi;
      case 'rideshare':
        return Icons.directions_car;
      default:
        return Icons.help;
    }
  }
}