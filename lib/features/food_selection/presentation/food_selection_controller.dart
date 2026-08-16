import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/food_catalog_storage.dart';
import '../domain/food_catalog.dart';

/// The food catalog, backed by [FoodCatalogStorage]. Seeded from
/// [FoodCatalog.breakfastMenu] on first run, then fully driven by user
/// add/remove actions (and Food Rotation's Save button) — every mutation
/// is persisted immediately.
class FoodCatalogController extends StateNotifier<List<FoodModel>> {
  FoodCatalogController(this._storage) : super(FoodCatalog.breakfastMenu) {
    _restore();
  }

  final FoodCatalogStorage _storage;

  Future<void> _restore() async {
    final saved = await _storage.load();
    if (saved != null) {
      state = saved;
    }
    // No saved list yet (first run): keep the in-memory default from the
    // constructor as-is. Deliberately not eagerly persisting it here —
    // doing so would race with an add/remove that runs before this
    // restore completes and could clobber it with the stale defaults.
    // The defaults are constant, so there's nothing lost by only
    // persisting on the first real mutation.
  }

  /// Adds [name] if it's non-empty and not already present
  /// (case-insensitive). Returns false without changing anything if it's a
  /// duplicate, so the UI can tell the user why nothing happened.
  Future<bool> addFood(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final alreadyExists =
        state.any((food) => food.name.toLowerCase() == trimmed.toLowerCase());
    if (alreadyExists) return false;

    state = [...state, FoodModel(name: trimmed)];
    await _storage.save(state);
    return true;
  }

  Future<void> removeFood(String name) async {
    state = state.where((food) => food.name != name).toList();
    await _storage.save(state);
  }

  /// Attaches Food Rotation settings (hours until use-by, employee, pH) to
  /// the catalog entry named [name] — picked up next time that food is
  /// selected. A no-op if the food isn't in the catalog (e.g. it was
  /// renamed on the print page, or removed since being selected).
  Future<void> saveFoodSettings(
    String name, {
    int? useByHours,
    String? employee,
    String? ph,
  }) async {
    final index = state.indexWhere((food) => food.name == name);
    if (index == -1) return;

    final updated = [...state];
    updated[index] = FoodModel(
      name: name,
      useByHours: useByHours,
      employee: employee,
      ph: ph,
    );
    state = updated;
    await _storage.save(state);
  }
}

final foodCatalogStorageProvider = Provider<FoodCatalogStorage>(
  (ref) => FoodCatalogStorage(),
);

final foodCatalogProvider =
    StateNotifierProvider<FoodCatalogController, List<FoodModel>>(
  (ref) => FoodCatalogController(ref.watch(foodCatalogStorageProvider)),
);

/// The current search box text, trimmed and lower-cased for matching.
final foodSearchQueryProvider = StateProvider<String>((ref) => '');

/// Food items matching [foodSearchQueryProvider], case-insensitive and
/// real-time. Empty query returns the full catalog.
final filteredFoodsProvider = Provider<List<FoodModel>>((ref) {
  final query = ref.watch(foodSearchQueryProvider).trim().toLowerCase();
  final all = ref.watch(foodCatalogProvider);
  if (query.isEmpty) return all;
  return all.where((food) => food.name.toLowerCase().contains(query)).toList();
});
