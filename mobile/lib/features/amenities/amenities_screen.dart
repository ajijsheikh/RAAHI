import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/amenity.dart';

class Amenity {
  final String id;
  final String name;
  final String kind; // 'stay' | 'food'
  final int priceInr;
  final double? rating;
  final bool verified;
  final String? phone;
  final String reason;
  final int walkMin;

  const Amenity({
    required this.id,
    required this.name,
    required this.kind,
    required this.priceInr,
    this.rating,
    this.verified = false,
    this.phone,
    this.reason = '',
    this.walkMin = 0,
  });

  factory Amenity.fromMap(Map<String, dynamic> m) => Amenity(
        id: (m['id'] ?? '').toString(),
        name: m['name'] ?? '',
        kind: m['kind'] ?? 'food',
        priceInr: (m['price_inr'] as num?)?.toInt() ?? 0,
        rating: (m['rating'] as num?)?.toDouble(),
        verified: m['verified'] ?? false,
        phone: m['phone'] as String?,
        reason: m['reason'] ?? '',
        walkMin: (m['walk_min'] as num?)?.toInt() ?? 0,
  );
}

class AmenitiesScreen extends ConsumerStatefulWidget {
  const AmenitiesScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends ConsumerState<AmenitiesScreen> {
  final List<Amenity> _demoAmenities = [
    Amenity(
      id: '1',
      name: 'Tech Serviced Stay',
      kind: 'stay',
      priceInr: 750,
      rating: 4.2,
      verified: true,
      phone: '+91332658741',
      reason: 'Verified, ₹350, 8 min walk on a lit main road.',
      walkMin: 8,
    ),
    Amenity(
      id: '2',
      name: 'Budget Inn',
      kind: 'stay',
      priceInr: 350,
      rating: 3.5,
      verified: true,
      phone: '+91332789456',
      reason: 'Just off Bidhannagar underpass — cheap but risky',
      walkMin: 5,
    ),
    Amenity(
      id: '3',
      name: 'Food Court 1',
      kind: 'food',
      priceInr: 80,
      rating: null,
      verified: false,
      phone: '+91332111111',
      reason: 'Food court near Sector V',
      walkMin: 3,
    ),
    Amenity(
      id: '4',
      name: 'Bhojohouse',
      kind: 'food',
      priceInr: 120,
      rating: 4.0,
      verified: true,
      phone: '+91332222222',
      reason: 'Popular spot at Bidhannagar Road',
      walkMin: 2,
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby amenities')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _demoAmenities.length,
        itemBuilder: (context, i) => _AmenityCard(amenity: _demoAmenities[i]),
      ),
    );
  }
}

class _AmenityCard extends StatelessWidget {
  const _AmenityCard({required this.amenity});

  final Amenity amenity;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          amenity.kind == 'stay' ? Icons.hotel : Icons.restaurant,
          size: 28,
        ),
        title: Row(
          children: [
            Flexible(child: Text(amenity.name)),
            if (amenity.verified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified, size: 16, color: Color(0xFF1B873F)),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('₹${amenity.priceInr} · ${amenity.walkMin} min walk'),
            if (amenity.reason.isNotEmpty)
              Text(
                amenity.reason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.phone),
          tooltip: 'Call',
          onPressed: amenity.phone == null || amenity.phone!.isEmpty
              ? null
              : () => launchUrl(Uri.parse('tel:${amenity.phone}')),
        ),
      ),
    );
  }
}