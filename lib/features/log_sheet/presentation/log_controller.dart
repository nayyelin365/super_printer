import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/log_location_repository.dart';
import '../data/log_preferences.dart';
import '../data/log_repository.dart';
import '../domain/log_entry.dart';
import '../domain/log_location.dart';
import '../domain/log_type.dart';

final logRepositoryProvider = Provider<LogRepository>((ref) => LogRepository());

final logLocationRepositoryProvider = Provider<LogLocationRepository>(
  (ref) => LogLocationRepository(),
);

final logPreferencesProvider = Provider<LogPreferences>((ref) => LogPreferences());

/// Live entries for one [LogType] — a `StreamProvider.family` so the table
/// updates immediately after add/edit/delete without any manual refetch.
final logEntriesProvider = StreamProvider.family<List<LogEntry>, LogType>((ref, logType) {
  return ref.watch(logRepositoryProvider).watchEntries(logType);
});

/// Live "Unit Name / Location" list, shared by every log type. Seeds the
/// Firestore collection with [defaultLogLocationNames] the first time this
/// provider is created against an empty collection.
final logLocationsProvider = StreamProvider<List<LogLocation>>((ref) async* {
  final repository = ref.watch(logLocationRepositoryProvider);
  await repository.ensureSeeded();
  yield* repository.watchLocations();
});

/// The entry currently open in the create/edit form — null means
/// "creating a new entry" (mirrors `editingAlarmProvider`'s pattern).
final editingLogEntryProvider = StateProvider<LogEntry?>((ref) => null);

/// Create/update/delete for log entries, plus the small bits of app state
/// (last-used initials, adding a location) the entry form needs — kept out
/// of the UI layer per the Log UI -> Controller -> Repository -> Firestore
/// separation.
class LogController {
  LogController(this._ref);

  final Ref _ref;

  Future<void> addEntry(LogEntry entry) async {
    await _ref.read(logRepositoryProvider).addEntry(entry);
    await _ref.read(logPreferencesProvider).saveLastInitials(entry.initials);
  }

  Future<void> updateEntry(LogEntry entry) async {
    await _ref.read(logRepositoryProvider).updateEntry(entry);
    await _ref.read(logPreferencesProvider).saveLastInitials(entry.initials);
  }

  Future<void> deleteEntry(String id) => _ref.read(logRepositoryProvider).deleteEntry(id);

  Future<String?> lastUsedInitials() => _ref.read(logPreferencesProvider).loadLastInitials();

  Future<LogLocation> addLocation(String name) =>
      _ref.read(logLocationRepositoryProvider).addLocation(name);
}

final logControllerProvider = Provider<LogController>((ref) => LogController(ref));
