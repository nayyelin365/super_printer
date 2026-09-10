import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/log_location_repository.dart';
import '../data/log_preferences.dart';
import '../data/log_record_repository.dart';
import '../domain/log_location.dart';
import '../domain/log_record.dart';
import '../domain/log_type.dart';

final logRecordRepositoryProvider = Provider<LogRecordRepository>(
  (ref) => LogRecordRepository(),
);

final logLocationRepositoryProvider = Provider<LogLocationRepository>(
  (ref) => LogLocationRepository(),
);

final logPreferencesProvider = Provider<LogPreferences>((ref) => LogPreferences());

/// Live records for one [LogType] — a `StreamProvider.family` so every list
/// screen updates immediately after add/edit/delete without a manual refetch.
final logRecordsProvider = StreamProvider.family<List<LogRecord>, LogType>((ref, logType) {
  return ref.watch(logRecordRepositoryProvider).watchRecords(logType);
});

/// Live "Unit Name / Location" list (also used for the STORE NAME / STORE
/// LOCATION header block), shared by every log. Seeds the Firestore
/// collection with [defaultLogLocationNames] the first time this provider is
/// created against an empty collection.
final logLocationsProvider = StreamProvider<List<LogLocation>>((ref) async* {
  final repository = ref.watch(logLocationRepositoryProvider);
  await repository.ensureSeeded();
  yield* repository.watchLocations();
});

/// The record currently open in the create/edit form — null means
/// "creating a new record" (mirrors `editingAlarmProvider`'s pattern). The
/// form screens read it back as their own concrete type.
final editingLogRecordProvider = StateProvider<LogRecord?>((ref) => null);

/// Create/update/delete for log records, plus the small bits of app state
/// (last-used initials, adding a location) the forms need — kept out of the
/// UI layer per UI -> Controller -> Repository -> Firestore.
class LogRecordController {
  LogRecordController(this._ref);

  final Ref _ref;

  Future<void> addRecord(LogRecord record) async {
    await _ref.read(logRecordRepositoryProvider).addRecord(record);
    await _ref.read(logPreferencesProvider).saveLastInitials(record.initials);
  }

  Future<void> updateRecord(LogRecord record) async {
    await _ref.read(logRecordRepositoryProvider).updateRecord(record);
    await _ref.read(logPreferencesProvider).saveLastInitials(record.initials);
  }

  Future<void> deleteRecord(String id) =>
      _ref.read(logRecordRepositoryProvider).deleteRecord(id);

  Future<String?> lastUsedInitials() => _ref.read(logPreferencesProvider).loadLastInitials();

  Future<LogLocation> addLocation(String name) =>
      _ref.read(logLocationRepositoryProvider).addLocation(name);
}

final logRecordControllerProvider =
    Provider<LogRecordController>((ref) => LogRecordController(ref));
