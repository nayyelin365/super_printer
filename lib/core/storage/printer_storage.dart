import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../printer/models/printer_config.dart';

/// Local persistence for the saved printer configuration.
///
/// Only one default printer is supported today (matching the settings UI),
/// but the storage format (a list) leaves room for multiple saved printers
/// later without a migration.
class PrinterStorage {
  static const _key = 'saved_printer_configs';

  Future<PrinterConfig?> loadDefault() async {
    final all = await loadAll();
    if (all.isEmpty) return null;
    return all.firstWhere((c) => c.isDefault, orElse: () => all.first);
  }

  Future<List<PrinterConfig>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PrinterConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(PrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    final updated = [
      config,
      ...all.where((c) => c.id != config.id),
    ];
    await prefs.setString(
      _key,
      jsonEncode(updated.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    final updated = all.where((c) => c.id != id).toList();
    await prefs.setString(
      _key,
      jsonEncode(updated.map((c) => c.toJson()).toList()),
    );
  }
}
