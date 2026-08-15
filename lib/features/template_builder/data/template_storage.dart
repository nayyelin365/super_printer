import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../label_printing/domain/label_template.dart';

/// Local persistence for user-created (custom) templates only — built-in
/// templates are code-defined and never touch storage.
///
/// Stored as a single versioned JSON object (not one key per template),
/// so the whole collection can be migrated together if the schema changes:
/// `{"schemaVersion": 1, "templates": [...]}`.
class TemplateStorage {
  static const _key = 'custom_templates';
  static const _currentSchemaVersion = 1;

  Future<List<LabelTemplate>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final migrated = _migrate(decoded);
    final templates = migrated['templates'] as List<dynamic>? ?? [];
    return templates
        .map((t) => LabelTemplate.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAll(List<LabelTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'schemaVersion': _currentSchemaVersion,
        'templates': templates.map((t) => t.toJson()).toList(),
      }),
    );
  }

  /// Upgrades an older saved schema to [_currentSchemaVersion] in place.
  /// There's only ever been version 1 so far; this is the seam future
  /// migrations plug into without breaking templates saved by older app
  /// versions.
  Map<String, dynamic> _migrate(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version == _currentSchemaVersion) return json;
    // No migrations defined yet — fall through and use the data as-is.
    return json;
  }
}
