import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/printer_storage.dart';
import 'models/printer_config.dart';
import 'printer_session_controller.dart';

/// Every saved printer configuration — not just the single one currently
/// active in [printerSessionProvider]. Backs the Settings screen's "Saved
/// Printers" list and the print page's label-size-filtered picker.
///
/// [PrinterStorage] already persisted a list; nothing above it ever
/// surfaced more than one entry until this controller.
class SavedPrintersController extends StateNotifier<List<PrinterConfig>> {
  SavedPrintersController(this._storage) : super(const []) {
    reload();
  }

  final PrinterStorage _storage;

  Future<void> reload() async {
    state = await _storage.loadAll();
  }

  Future<void> delete(String id) async {
    await _storage.delete(id);
    await reload();
  }
}

final savedPrintersProvider =
    StateNotifierProvider<SavedPrintersController, List<PrinterConfig>>(
  (ref) => SavedPrintersController(ref.watch(printerStorageProvider)),
);
