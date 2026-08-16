import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/food_catalog.dart';

/// Local persistence for the food catalog, stored as a single versioned
/// JSON object (mirrors `TemplateStorage`'s pattern):
/// `{"schemaVersion": 1, "items": [...]}`.
///
/// `null` from [load] means "never saved" (first run) — the controller
/// seeds from [FoodCatalog]'s defaults in that case and persists them, so
/// afterwards the saved list is always the source of truth.
class FoodCatalogStorage {
  // Different key than the old plain-string-list format this replaced, so
  // there's no stale-type read on upgrade.
  static const _key = 'food_catalog_items_v2';
  static const _currentSchemaVersion = 1;

  Future<List<FoodModel>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final migrated = _migrate(decoded);
    final items = migrated['items'] as List<dynamic>? ?? [];
    return items.map((i) => FoodModel.fromJson(i as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<FoodModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'schemaVersion': _currentSchemaVersion,
        'items': items.map((i) => i.toJson()).toList(),
      }),
    );
  }

  /// Upgrades an older saved schema to [_currentSchemaVersion] in place.
  /// There's only ever been version 1 so far; this is the seam future
  /// migrations plug into without breaking catalogs saved by older app
  /// versions.
  Map<String, dynamic> _migrate(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version == _currentSchemaVersion) return json;
    // No migrations defined yet — fall through and use the data as-is.
    return json;
  }
}
