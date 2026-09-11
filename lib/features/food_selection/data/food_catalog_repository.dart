import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/food_catalog.dart';

/// Firestore-backed storage for the food catalog — one document per food,
/// keyed by the food's own (trimmed) name, so `addFood`/`removeFood`/
/// `saveFoodSettings` (all keyed by name today) don't need a separate id.
/// Replaces the earlier `FoodCatalogStorage`, which kept this only on the
/// device via `SharedPreferences` — the catalog is now shared across every
/// device, like the rest of the app's kitchen data.
class FoodCatalogRepository {
  FoodCatalogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('food_catalog');

  /// Live catalog, sorted by name — [FoodCatalogController] mirrors this
  /// into its (synchronous) state so every screen keeps reading a plain
  /// `List<FoodModel>` from `foodCatalogProvider`.
  Stream<List<FoodModel>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) => FoodModel.fromJson(doc.data())).toList();
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  /// Writes [FoodCatalog.breakfastMenu] the first time this is ever called
  /// against an empty collection — a one-time seed, never re-run once any
  /// food (default or user-added) already exists. Mirrors
  /// `LogLocationRepository.ensureSeeded`.
  Future<void> ensureSeeded() async {
    final existing = await _collection.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (final food in FoodCatalog.breakfastMenu) {
      batch.set(_collection.doc(food.name), food.toJson());
    }
    await batch.commit();
  }

  /// Creates or fully overwrites the food named `food.name`.
  Future<void> setFood(FoodModel food) => _collection.doc(food.name).set(food.toJson());

  Future<void> deleteFood(String name) => _collection.doc(name).delete();
}
