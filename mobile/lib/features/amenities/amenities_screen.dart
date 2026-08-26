import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:raahi/domain/models/amenity.dart';
import 'package:raahi/features/amenities/amenities_provider.dart';
import 'package:raahi/features/active_trip/active_trip_provider.dart';
import 'package:raahi/main.dart';

class AmenitiesScreen extends ConsumerWidget {
  const AmenitiesScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amenities = ref.watch(amenitiesProvider);
    final filter = ref.watch(amenitiesFilterProvider);
    final budgetRemaining = ref.watch(budgetRemainingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amenities'),
        actions: [
          _buildFilterChips(ref, filter),
        ],
      ),
      body: amenities.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildBudgetHeader(budgetRemaining),
                const Expanded(child: AmenityList()),
              ],
            ),
    );
  }

  Widget _buildFilterChips(WidgetRef ref, AmenityFilter currentFilter) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterChip(
          label: 'All',
          isSelected: currentFilter == AmenityFilter.all,
          onSelected: (selected) =>
              ref.read(amenitiesFilterProvider.notifier).state = selected ? AmenityFilter.all : AmenityFilter.food,
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Stay',
          isSelected: currentFilter == AmenityFilter.stay,
          onSelected: (selected) =>
              ref.read(amenitiesFilterProvider.notifier).state = selected ? AmenityFilter.stay : AmenityFilter.all,
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Food',
          isSelected: currentFilter == AmenityFilter.food,
          onSelected: (selected) =>
              ref.read(amenitiesFilterProvider.notifier).state = selected ? AmenityFilter.food : AmenityFilter.all,
        ),
      ],
    );
  }

  Widget _buildBudgetHeader(int budget) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '₹$budget remaining',
            style: GoogleFonts.openSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.openSans(
          color: isSelected ? Colors.white : Colors.green[700],
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.green[700],
      onSelected: onSelected,
    );
  }
}

class AmenityList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amenities = ref.watch(amenitiesProvider);
    final budgetRemaining = ref.watch(budgetRemainingProvider);

    if (amenities.isEmpty) {
      return const Center(child: Text('No amenities available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: amenities.length,
      itemBuilder: (context, index) {
        final amenity = amenities[index];
        return _AmenityCard(amenity: amenity);
      },
    );
  }
}

class _AmenityCard extends StatelessWidget {
  final Amenity amenity;

  const _AmenityCard({required this.amenity});

  @override
  Widget build(BuildContext context) {
    final cSafe = Color(0xFF1B873F);
    final cCaution = Color(0xFFB77900);
    final cRisk = Color(0xFFC62828);

    Color safetyDotColor() {
      if (amenity.score >= 0.7) return cSafe;
      if (amenity.score >= 0.4) return cCaution;
      return cRisk;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: amenity.verified ? Colors.green[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            amenity.kind == 'stay' ? Icons.hotel : Icons.restaurant,
            color: amenity.verified ? Colors.green : null,
            size: 28,
          ),
        ),
        title: Text(
          amenity.name,
          style: GoogleFonts.openSans(
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹${amenity.priceInr}',
              style: GoogleFonts.openSans(
                fontSize: 14,
                color: Colors.green[700],
              ),
            ),
            Text(
              '${amenity.walkMin} min walk',
              style: GoogleFonts.openSans(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: safetyDotColor(),
                shape: BoxDecoration.shape.circle,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                final uri = Uri.parse('tel:${amenity.phone ?? ''}');
                if (canLaunchUrl(uri)) {
                  launchUrl(uri);
                }
              },
              child: Text(
                'Call',
                style: GoogleFonts.openSans(
                  color: Colors.green[700],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}