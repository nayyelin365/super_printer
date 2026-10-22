import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for a "labels printed today" counter — a single
/// `{"date": "YYYY-MM-DD", "count": N}` entry under [key]. Whether a saved
/// date still counts as "today" is the caller's call, not this storage's —
/// it just reads back whatever was last saved. [key] lets each template
/// that wants its own daily count (Poke Bowl, Sushi Template Label) keep a
/// separate one rather than sharing a single running total.
class PrintCountStorage {
  PrintCountStorage({this.key = 'daily_print_count'});

  final String key;

  Future<({String date, int count})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (date: decoded['date'] as String, count: decoded['count'] as int);
  }

  Future<void> save({required String date, required int count}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode({'date': date, 'count': count}));
  }
}
