import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/print_count_storage.dart';

/// Number of custom poke bowl labels printed today, shown beside the Print
/// button (only for that label). Bumped by [LabelPrintController.print]
/// after a successful poke bowl print (by however many copies were just
/// printed) and persisted per calendar day.
///
/// The count only ever belongs to one calendar day ([_countDate]): on a new
/// day it starts back at 0. That reset happens three ways, so it never
/// depends on the app being restarted —
///  * at startup, a saved count from another date is ignored ([_restore]);
///  * while the app stays open across midnight, a timer resets it right at
///    the day rollover ([_scheduleMidnightReset]);
///  * as a safety net (device asleep through midnight, timer fired late),
///    [increment] re-checks the date before adding.
class PrintCountController extends StateNotifier<int> {
  PrintCountController(this._storage) : super(0) {
    _restore();
    _scheduleMidnightReset();
  }

  final PrintCountStorage _storage;
  Timer? _midnightTimer;

  /// The calendar day [state] is counting — compared against
  /// [_todayKey] to tell whether the count has gone stale.
  String _countDate = _todayKeyNow();

  static String _todayKeyNow() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _todayKey() => _todayKeyNow();

  Future<void> _restore() async {
    final saved = await _storage.load();
    if (saved != null && saved.date == _todayKey()) {
      _countDate = saved.date;
      state = saved.count;
    }
    // A saved date that isn't today (or no saved count at all): leave
    // state at 0 rather than persisting that reset immediately — nothing
    // is lost since the next real print writes the fresh count anyway.
  }

  /// Fires just after the next local midnight, zeroes the count for the new
  /// day, then re-arms for the following midnight.
  void _scheduleMidnightReset() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer?.cancel();
    _midnightTimer = Timer(nextMidnight.difference(now) + const Duration(seconds: 1), () {
      _resetIfNewDay();
      _scheduleMidnightReset();
    });
  }

  void _resetIfNewDay() {
    final today = _todayKey();
    if (_countDate == today) return;
    _countDate = today;
    state = 0;
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  /// Adds [amount] (the quantity just printed) to today's count.
  Future<void> increment(int amount) async {
    _resetIfNewDay();
    final newCount = state + amount;
    state = newCount;
    await _storage.save(date: _countDate, count: newCount);
  }
}

final printCountStorageProvider = Provider<PrintCountStorage>(
  (ref) => PrintCountStorage(),
);

final printCountProvider = StateNotifierProvider<PrintCountController, int>(
  (ref) => PrintCountController(ref.watch(printCountStorageProvider)),
);
