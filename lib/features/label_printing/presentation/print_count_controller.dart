import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/print_count_storage.dart';

/// Number of custom poke bowl labels printed today, shown beside the Print
/// button (only for that label). Bumped by [LabelPrintController.print]
/// after a successful poke bowl print (by however many copies were just
/// printed) and persisted per calendar day — on a
/// new day the saved count belongs to a different date, so it's ignored
/// and today starts back at 0.
class PrintCountController extends StateNotifier<int> {
  PrintCountController(this._storage) : super(0) {
    _restore();
  }

  final PrintCountStorage _storage;

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _restore() async {
    final saved = await _storage.load();
    if (saved != null && saved.date == _todayKey()) {
      state = saved.count;
    }
    // A saved date that isn't today (or no saved count at all): leave
    // state at 0 rather than persisting that reset immediately — nothing
    // is lost since the next real print writes the fresh count anyway.
  }

  /// Adds [amount] (the quantity just printed) to today's count.
  Future<void> increment(int amount) async {
    final newCount = state + amount;
    state = newCount;
    await _storage.save(date: _todayKey(), count: newCount);
  }
}

final printCountStorageProvider = Provider<PrintCountStorage>(
  (ref) => PrintCountStorage(),
);

final printCountProvider = StateNotifierProvider<PrintCountController, int>(
  (ref) => PrintCountController(ref.watch(printCountStorageProvider)),
);
