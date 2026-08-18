import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for edits to the Poke Bowl / Burrito base/extra price
/// names and amounts — stored as a single versioned JSON object (mirrors
/// `TemplateStorage`'s pattern): `{"schemaVersion": 1, "basePrices": [...],
/// "extras": [...]}`, where each entry is `{"id", "label", "amount"}`.
///
/// Only overrides are stored, keyed by the option's stable `id` — colors
/// and the set of options themselves stay code-defined (see
/// `defaultBasePriceOptions`/`defaultExtraPriceOptions`); this just carries
/// the seller's edited name/price for each, merged in by
/// `PokeBowlPricingController`.
class PokeBowlPricingStorage {
  static const _key = 'poke_bowl_pricing_overrides';
  static const _currentSchemaVersion = 1;

  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    return _migrate(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save({
    required List<Map<String, dynamic>> basePrices,
    required List<Map<String, dynamic>> extras,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'schemaVersion': _currentSchemaVersion,
        'basePrices': basePrices,
        'extras': extras,
      }),
    );
  }

  /// Upgrades an older saved schema to [_currentSchemaVersion] in place.
  /// There's only ever been version 1 so far; this is the seam future
  /// migrations plug into without breaking overrides saved by older app
  /// versions.
  Map<String, dynamic> _migrate(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version == _currentSchemaVersion) return json;
    // No migrations defined yet — fall through and use the data as-is.
    return json;
  }
}
