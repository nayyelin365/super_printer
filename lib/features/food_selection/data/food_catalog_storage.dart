import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for the food catalog, stored as a plain string list.
///
/// `null` from [load] means "never saved" (first run) — the controller
/// seeds from [FoodCatalog]'s defaults in that case and persists them, so
/// afterwards the saved list is always the source of truth.
class FoodCatalogStorage {
  static const _key = 'food_catalog_items';

  Future<List<String>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key);
  }

  Future<void> save(List<String> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, items);
  }
}
