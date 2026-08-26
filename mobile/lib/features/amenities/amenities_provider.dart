import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raahi/domain/models/amenity.dart';

enum AmenityFilter { all, stay, food }

final amenitiesProvider = StateNotifierProvider<AmenityNotifier, List<Amenity>>((ref) {
  return AmenityNotifier();
});

final amenitiesFilterProvider = StateProvider<AmenityFilter>((ref) => AmenityFilter.all);

final budgetRemainingProvider = StateProvider<int>((ref) => 200);

class AmenityNotifier extends StateNotifier<List<Amenity>> {
  AmenityNotifier() : super(const []);

  void setAmenities(List<Amenity> amenities) {
    state = List.from(amenities);
  }

  List<Amenity> get filteredAmenities {
    final filter = ref.watch(amenitiesFilterProvider);
    final all = state;
    switch (filter) {
      case AmenityFilter.all:
        return all;
      case AmenityFilter.stay:
        return all.where((a) => a.kind == 'stay').toList();
      case AmenityFilter.food:
        return all.where((a) => a.kind == 'food').toList();
    }
  }

  List<Amenity> get sortedAmenities {
    return List.from(filteredAmenities..sort((a, b) => a.score.compareTo(b.score)));
  }
}