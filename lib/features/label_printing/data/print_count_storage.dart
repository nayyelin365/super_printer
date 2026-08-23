import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for the "labels printed today" counter — a single
/// `{"date": "YYYY-MM-DD", "count": N}` entry. Whether a saved date still
/// counts as "today" is the caller's call, not this storage's — it just
/// reads back whatever was last saved.
class PrintCountStorage {
  static const _key = 'daily_print_count';

  Future<({String date, int count})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (date: decoded['date'] as String, count: decoded['count'] as int);
  }

  Future<void> save({required String date, required int count}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({'date': date, 'count': count}));
  }
}
