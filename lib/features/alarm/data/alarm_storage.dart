import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/alarm.dart';

/// Local persistence for alarms — a single versioned JSON object (mirrors
/// `TemplateStorage`'s pattern): `{"schemaVersion": 1, "alarms": [...]}`.
class AlarmStorage {
  static const _key = 'alarms';
  static const _currentSchemaVersion = 1;

  Future<List<Alarm>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final migrated = _migrate(decoded);
    final alarms = migrated['alarms'] as List<dynamic>? ?? [];
    return alarms.map((a) => Alarm.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<void> saveAll(List<Alarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'schemaVersion': _currentSchemaVersion,
        'alarms': alarms.map((a) => a.toJson()).toList(),
      }),
    );
  }

  /// Upgrades an older saved schema to [_currentSchemaVersion] in place.
  /// There's only ever been version 1 so far; this is the seam future
  /// migrations plug into without breaking alarms saved by older app
  /// versions.
  Map<String, dynamic> _migrate(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version == _currentSchemaVersion) return json;
    // No migrations defined yet — fall through and use the data as-is.
    return json;
  }
}
