import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/alarm/domain/alarm.dart';
import 'package:super_printer/features/alarm/domain/alarm_sound.dart';

void main() {
  group('Alarm.repeatLabel', () {
    test('no days selected reads as Once', () {
      final alarm = Alarm(id: '1', hour: 7, minute: 30, title: 'Wake Up', repeatDays: const {});
      expect(alarm.repeatLabel, 'Once');
    });

    test('all seven days reads as Every day', () {
      final alarm = Alarm(
        id: '1',
        hour: 7,
        minute: 30,
        title: 'Wake Up',
        repeatDays: const {1, 2, 3, 4, 5, 6, 7},
      );
      expect(alarm.repeatLabel, 'Every day');
    });

    test('Mon-Fri reads as Weekdays', () {
      final alarm = Alarm(
        id: '1',
        hour: 7,
        minute: 30,
        title: 'Work',
        repeatDays: const {1, 2, 3, 4, 5},
      );
      expect(alarm.repeatLabel, 'Weekdays');
    });

    test('Sat+Sun reads as Weekends', () {
      final alarm = Alarm(
        id: '1',
        hour: 9,
        minute: 0,
        title: 'Sleep in',
        repeatDays: const {6, 7},
      );
      expect(alarm.repeatLabel, 'Weekends');
    });

    test('a custom subset lists the day names in order', () {
      final alarm = Alarm(
        id: '1',
        hour: 9,
        minute: 0,
        title: 'Study',
        repeatDays: const {5, 1, 3},
      );
      expect(alarm.repeatLabel, 'Mon, Wed, Fri');
    });
  });

  group('Alarm.timeLabel', () {
    test('formats midnight, noon, and a PM time in 12-hour form', () {
      expect(
        Alarm(id: '1', hour: 0, minute: 0, title: 'x').timeLabel,
        '12:00 AM',
      );
      expect(
        Alarm(id: '1', hour: 12, minute: 0, title: 'x').timeLabel,
        '12:00 PM',
      );
      expect(
        Alarm(id: '1', hour: 21, minute: 5, title: 'x').timeLabel,
        '09:05 PM',
      );
    });
  });

  group('Alarm.nextOccurrence', () {
    test('a one-time alarm always returns oneTimeDate + time, never rolling forward', () {
      final scheduledDate = DateTime(2026, 8, 20);
      final alarm = Alarm(
        id: '1',
        hour: 7,
        minute: 30,
        title: 'Once',
        oneTimeDate: scheduledDate,
      );
      // Even "now" being long after the scheduled moment doesn't change it.
      final result = alarm.nextOccurrence(now: DateTime(2026, 8, 25));
      expect(result, DateTime(2026, 8, 20, 7, 30));
    });

    test('a repeating alarm returns the next matching weekday after now', () {
      // Thursday 2026-08-20, alarm set for Mon/Wed/Fri at 07:30.
      final now = DateTime(2026, 8, 20, 10, 0);
      final alarm = Alarm(
        id: '1',
        hour: 7,
        minute: 30,
        title: 'MWF',
        repeatDays: const {1, 3, 5},
      );
      final next = alarm.nextOccurrence(now: now);
      // Next Friday (2026-08-21) at 07:30.
      expect(next, DateTime(2026, 8, 21, 7, 30));
    });
  });

  group('Alarm.nextOccurrenceOfWeekday', () {
    test('finds the next occurrence of a specific weekday, skipping today if already past', () {
      // Friday 2026-08-21, 08:00 — Friday's own 07:30 slot has passed.
      final now = DateTime(2026, 8, 21, 8, 0);
      final alarm = Alarm(id: '1', hour: 7, minute: 30, title: 'Fri', repeatDays: const {5});
      final next = alarm.nextOccurrenceOfWeekday(5, now: now);
      // Rolls to next Friday, not today.
      expect(next, DateTime(2026, 8, 28, 7, 30));
    });
  });

  group('Alarm JSON round-trip', () {
    test('toJson/fromJson preserves every field, including repeat days and oneTimeDate', () {
      final alarm = Alarm(
        id: 'abc-123',
        hour: 6,
        minute: 45,
        title: 'Gym',
        note: 'Bring water bottle',
        enabled: false,
        repeatDays: const {2, 4},
        soundId: 'alarm2',
        repeatSound: true,
      );
      final restored = Alarm.fromJson(alarm.toJson());

      expect(restored.id, alarm.id);
      expect(restored.hour, alarm.hour);
      expect(restored.minute, alarm.minute);
      expect(restored.title, alarm.title);
      expect(restored.note, alarm.note);
      expect(restored.enabled, alarm.enabled);
      expect(restored.repeatDays, alarm.repeatDays);
      expect(restored.oneTimeDate, isNull);
      expect(restored.soundId, 'alarm2');
      expect(restored.repeatSound, isTrue);
    });

    test('repeatSound and soundId default to off/default when absent from saved JSON', () {
      final alarm = Alarm(id: 'x', hour: 1, minute: 0, title: 'x');
      final restored = Alarm.fromJson(alarm.toJson());
      expect(restored.repeatSound, isFalse);
      expect(restored.soundId, defaultAlarmSoundId);
    });

    test('a one-time alarm round-trips its oneTimeDate', () {
      final alarm = Alarm(
        id: 'one-time',
        hour: 6,
        minute: 0,
        title: 'Flight',
        oneTimeDate: DateTime(2026, 9, 1),
      );
      final restored = Alarm.fromJson(alarm.toJson());
      expect(restored.oneTimeDate, DateTime(2026, 9, 1));
    });
  });

  group('stableAlarmBaseId', () {
    test('is deterministic for the same id', () {
      expect(stableAlarmBaseId('same-id'), stableAlarmBaseId('same-id'));
    });

    test('differs for different ids (no accidental collisions for typical uuids)', () {
      expect(
        stableAlarmBaseId('11111111-1111-1111-1111-111111111111'),
        isNot(stableAlarmBaseId('22222222-2222-2222-2222-222222222222')),
      );
    });

    test('stays within a range safe for `* 10 + subId` as a 32-bit notification id', () {
      final id = stableAlarmBaseId('some-uuid-value-here');
      expect(id * 10 + 9, lessThan(1 << 31));
      expect(id, greaterThanOrEqualTo(0));
    });
  });
}
