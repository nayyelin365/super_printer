import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/food_catalog.dart';

/// The full food catalog. Swapping [FoodCatalog] for an API/database
/// repository later only means changing this provider's implementation.
final foodCatalogProvider = Provider<List<String>>(
  (ref) => FoodCatalog.breakfastMenu,
);

/// The current search box text, trimmed and lower-cased for matching.
final foodSearchQueryProvider = StateProvider<String>((ref) => '');

/// Food items matching [foodSearchQueryProvider], case-insensitive and
/// real-time. Empty query returns the full catalog.
final filteredFoodsProvider = Provider<List<String>>((ref) {
  final query = ref.watch(foodSearchQueryProvider).trim().toLowerCase();
  final all = ref.watch(foodCatalogProvider);
  if (query.isEmpty) return all;
  return all.where((food) => food.toLowerCase().contains(query)).toList();
});
