import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/log_sheet/domain/log_entry.dart';
import 'package:super_printer/features/log_sheet/domain/log_type.dart';

void main() {
  group('LogType', () {
    test('id matches the enum name (Firestore field value / route segment)', () {
      expect(LogType.sushiRice.id, 'sushiRice');
      expect(LogType.temperature.id, 'temperature');
      expect(LogType.values.byName('coolPrep'), LogType.coolPrep);
    });
  });

  group('LogEntry', () {
    LogEntry buildEntry({double? targetTemp, String correctiveAction = ''}) {
      return LogEntry(
        id: 'abc123',
        logType: LogType.temperature,
        date: DateTime(2026, 8, 22),
        hour: 14,
        minute: 5,
        foodName: 'Atlantic Salmon',
        targetTemp: targetTemp,
        locationId: 'loc1',
        locationName: 'Walk-in Cooler',
        actualTemp: 38,
        passFail: PassFail.pass,
        correctiveAction: correctiveAction,
        initials: 'nl',
      );
    }

    test('dateLabel and timeLabel format for display', () {
      final entry = buildEntry(targetTemp: 32);
      expect(entry.dateLabel, '08/22/2026');
      expect(entry.timeLabel, '02:05 PM');
    });

    test('targetTempLabel falls back to a dash when no target temp was set', () {
      expect(buildEntry(targetTemp: 32).targetTempLabel, '32°F');
      expect(buildEntry().targetTempLabel, '-');
    });

    test('correctiveActionLabel shows None when empty, trimmed text otherwise', () {
      expect(buildEntry().correctiveActionLabel, 'None');
      expect(buildEntry(correctiveAction: 'Moved to walk-in').correctiveActionLabel, 'Moved to walk-in');
    });

    test('toMap/fromMap round-trip preserves every field', () {
      final entry = buildEntry(targetTemp: 32, correctiveAction: 'Discarded');
      final map = entry.toMap();
      map['createdAtMillis'] = 1000;
      map['updatedAtMillis'] = 2000;

      final restored = LogEntry.fromMap('abc123', map);

      expect(restored.id, entry.id);
      expect(restored.logType, entry.logType);
      expect(restored.date, entry.date);
      expect(restored.hour, entry.hour);
      expect(restored.minute, entry.minute);
      expect(restored.foodName, entry.foodName);
      expect(restored.targetTemp, entry.targetTemp);
      expect(restored.locationId, entry.locationId);
      expect(restored.locationName, entry.locationName);
      expect(restored.actualTemp, entry.actualTemp);
      expect(restored.passFail, entry.passFail);
      expect(restored.correctiveAction, entry.correctiveAction);
      expect(restored.initials, entry.initials);
      expect(restored.createdAt, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(restored.updatedAt, DateTime.fromMillisecondsSinceEpoch(2000));
    });

    test('toMap omits targetTemp entirely when null (no duplicated Food data to sync)', () {
      final map = buildEntry().toMap();
      expect(map.containsKey('targetTemp'), isFalse);
    });
  });
}
