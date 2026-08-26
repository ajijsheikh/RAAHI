class Amenity {
  final String id;
  final String name;
  final String kind; // 'stay' or 'food'
  final int priceInr;
  final double rating;
  final bool verified;
  final String? phone;
  final String? address;
  final String reason;
  final int walkMin;
  final double score; // safety-weighted score

  Amenity({
    required this.id,
    required this.name,
    required this.kind,
    required this.priceInr,
    this.rating = 0,
    this.verified = false,
    this.phone,
    this.address,
    required this.reason,
    required this.walkMin,
    required this.score,
  });

  factory Amenity.fromMap(Map<String, dynamic> map) {
    return Amenity(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      kind: map['kind'] ?? 'food',
      priceInr: map['price_inr'] ?? 0,
      rating: map['rating'] ?? 0,
      verified: map['verified'] ?? false,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      reason: map['reason'] ?? '',
      walkMin: map['walk_min'] ?? 0,
      score: (map['score'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'kind': kind,
      'price_inr': priceInr,
      'rating': rating,
      'verified': verified,
      'phone': phone,
      'address': address,
      'reason': reason,
      'walk_min': walkMin,
      'score': score,
    };
  }
}