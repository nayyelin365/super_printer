import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/food_catalog_repository.dart';
import '../domain/food_catalog.dart';

/// The food catalog, backed by [FoodCatalogRepository] (Firestore, shared
/// across every device) — seeded from [FoodCatalog.breakfastMenu] on first
/// run, then fully driven by user add/remove actions (and Food Rotation's
/// Save button).
///
/// Still a plain `List<FoodModel>` [StateNotifier] rather than an
/// `AsyncValue`-returning stream provider: the controller subscribes to
/// Firestore itself and mirrors every update into [state], so none of the
/// screens/controllers that already do `ref.watch(foodCatalogProvider)`
/// (a synchronous list) needed to change — see the class doc on
/// [FoodCatalog] for why this swap was designed to be invisible to them.
class FoodCatalogController extends StateNotifier<List<FoodModel>> {
  FoodCatalogController(this._repository) : super(FoodCatalog.breakfastMenu) {
    _init();
  }

  final FoodCatalogRepository _repository;
  StreamSubscription<List<FoodModel>>? _subscription;

  Future<void> _init() async {
    await _repository.ensureSeeded();
    _subscription = _repository.watchAll().listen((items) => state = items);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Adds [name] if it's non-empty and not already present
  /// (case-insensitive). Returns false without changing anything if it's a
  /// duplicate, so the UI can tell the user why nothing happened. [color]
  /// is the category color picked in the add-food dialog, shown as the
  /// card's accent; [targetTemperature] is the optional target
  /// storage/holding temperature (°F).
  Future<bool> addFood(String name, {Color? color, double? targetTemperature}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final alreadyExists =
        state.any((food) => food.name.toLowerCase() == trimmed.toLowerCase());
    if (alreadyExists) return false;

    await _repository.setFood(
      FoodModel(name: trimmed, color: color, targetTemperature: targetTemperature),
    );
    // `state` updates itself once the `watchAll()` listener above observes
    // this write — no need to set it optimistically here.
    return true;
  }

  Future<void> removeFood(String name) => _repository.deleteFood(name);

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
    final existing = state.where((food) => food.name == name).firstOrNull;
    if (existing == null) return;

    await _repository.setFood(
      existing.copyWith(
        useByHours: () => useByHours,
        employee: () => employee,
        ph: () => ph,
      ),
    );
  }
}

final foodCatalogRepositoryProvider = Provider<FoodCatalogRepository>(
  (ref) => FoodCatalogRepository(),
);

final foodCatalogProvider =
    StateNotifierProvider<FoodCatalogController, List<FoodModel>>(
  (ref) => FoodCatalogController(ref.watch(foodCatalogRepositoryProvider)),
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
