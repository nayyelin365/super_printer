import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/log_sheet/domain/cooling_record.dart';
import 'package:super_printer/features/log_sheet/domain/log_record.dart';
import 'package:super_printer/features/log_sheet/domain/log_type.dart';
import 'package:super_printer/features/log_sheet/domain/rice_hot_hold_record.dart';
import 'package:super_printer/features/log_sheet/domain/sushi_bar_temp_record.dart';
import 'package:super_printer/features/log_sheet/domain/sushi_rice_ph_record.dart';

void main() {
  group('LogType', () {
    test('id matches the enum name (Firestore field value / route segment)', () {
      expect(LogType.sushiRicePh.id, 'sushiRicePh');
      expect(LogType.values.byName('cooling'), LogType.cooling);
      expect(LogType.values.length, 4);
    });

    test('idPrefix is unique per type', () {
      final prefixes = LogType.values.map((t) => t.idPrefix).toSet();
      expect(prefixes.length, LogType.values.length);
    });
  });

  group('DayTime', () {
    test('round-trips through minutes-since-midnight', () {
      const t = DayTime(14, 5);
      expect(t.minutesSinceMidnight, 845);
      expect(DayTime.fromMinutes(845), t);
      expect(DayTime.fromMinutesOrNull(null), isNull);
    });

    test('formats as 12-hour with AM/PM', () {
      expect(const DayTime(0, 0).label, '12:00 AM');
      expect(const DayTime(9, 30).label, '9:30 AM');
      expect(const DayTime(14, 5).label, '2:05 PM');
    });
  });

  group('SushiRicePhRecord', () {
    test('toMap/fromMap round-trip preserves every field', () {
      final record = SushiRicePhRecord(
        id: 'r1',
        date: DateTime(2026, 8, 23),
        phMeterCalibrated: true,
        riceBatchNo: 'Batch-2026-0002',
        timeStartCooking: const DayTime(8, 0),
        timeCooked: const DayTime(8, 40),
        timeAcidified: const DayTime(9, 0),
        ricePh: 4.1,
        phAfterCorrected: 4.0,
        amountAddingVinegar: '50 ml',
        inRangeAfterCorrection: true,
        discardOutOfRangeRice: false,
        timeRiceAllUsed: DateTime(2026, 8, 23, 15, 30),
        discardTimeAfterExpiry: const DayTime(16, 0),
        initials: 'NL',
      );
      final map = record.toMap()
        ..['createdAtMillis'] = 1000
        ..['updatedAtMillis'] = 2000;
      final restored = SushiRicePhRecord.fromMap('r1', map);

      expect(restored.date, record.date);
      expect(restored.phMeterCalibrated, true);
      expect(restored.riceBatchNo, 'Batch-2026-0002');
      expect(restored.timeStartCooking, const DayTime(8, 0));
      expect(restored.ricePh, 4.1);
      expect(restored.inRange, true);
      expect(restored.phAfterCorrected, 4.0);
      expect(restored.amountAddingVinegar, '50 ml');
      expect(restored.timeRiceAllUsed, DateTime(2026, 8, 23, 15, 30));
      expect(restored.initials, 'NL');
      expect(restored.createdAt, DateTime.fromMillisecondsSinceEpoch(1000));
    });

    test('omits null optional times/answers from the stored map', () {
      final record = SushiRicePhRecord(
        id: '',
        date: DateTime(2026, 8, 23),
      );
      final map = record.toMap();
      expect(map.containsKey('timeStartCookingMin'), isFalse);
      expect(map.containsKey('ricePh'), isFalse);
      expect(map.containsKey('phMeterCalibrated'), isFalse);
    });

    test('Yes/No fields default to null (unanswered), not false', () {
      final record = SushiRicePhRecord(id: '', date: DateTime.now());
      expect(record.phMeterCalibrated, isNull);
      expect(record.inRangeAfterCorrection, isNull);
      expect(record.discardOutOfRangeRice, isNull);
    });

    test('inRange is derived from ricePh against the 4.2 threshold, not stored', () {
      SushiRicePhRecord withPh(double? ph) =>
          SushiRicePhRecord(id: '', date: DateTime(2026, 8, 23), ricePh: ph);

      expect(withPh(null).inRange, isNull);
      expect(withPh(4.1).inRange, isTrue);
      expect(withPh(4.2).inRange, isTrue);
      expect(withPh(4.3).inRange, isFalse);
      expect(withPh(4.3).toMap().containsKey('inRange'), isFalse);
    });
  });

  group('SushiBarTempRecord', () {
    test('round-trips including the time slot enum and a dynamic reading list', () {
      final record = SushiBarTempRecord(
        id: 'r2',
        date: DateTime(2026, 9, 1),
        timeSlot: TempTimeSlot.threePm,
        readings: const [
          UnitTempReading(locationId: 'l1', locationName: 'Display Case', tempF: 38),
          UnitTempReading(locationId: 'l2', locationName: 'Freezer', tempF: 5),
        ],
        calibrated: true,
        initials: 'AB',
      );
      final restored = SushiBarTempRecord.fromMap('r2', record.toMap());
      expect(restored.timeSlot, TempTimeSlot.threePm);
      expect(restored.readingFor('l1')?.tempF, 38);
      expect(restored.readingFor('l2')?.tempF, 5);
      expect(restored.readingFor('missing'), isNull);
      expect(restored.calibrated, true);
      expect(restored.timeSortKey, 15 * 60);
    });

    test('readings list is not fixed to three units — any count works', () {
      final record = SushiBarTempRecord(
        id: '',
        date: DateTime(2026, 9, 1),
        timeSlot: TempTimeSlot.nineAm,
        readings: const [
          UnitTempReading(locationId: 'l1', locationName: 'Unit A', tempF: 30),
          UnitTempReading(locationId: 'l2', locationName: 'Unit B', tempF: 31),
          UnitTempReading(locationId: 'l3', locationName: 'Unit C', tempF: 32),
          UnitTempReading(locationId: 'l4', locationName: 'Unit D', tempF: 33),
          UnitTempReading(locationId: 'l5', locationName: 'Unit E', tempF: 34),
        ],
      );
      expect(record.readings, hasLength(5));
      expect(SushiBarTempRecord.fromMap('', record.toMap()).readings, hasLength(5));
    });

    test('calibrated defaults to null (unanswered), not false', () {
      final record = SushiBarTempRecord(
        id: '',
        date: DateTime(2026, 9, 1),
        timeSlot: TempTimeSlot.nineAm,
      );
      expect(record.calibrated, isNull);
      expect(record.toMap().containsKey('calibrated'), isFalse);
      expect(record.readings, isEmpty);
    });
  });

  group('CoolingRecord', () {
    test('round-trips the cooling-start datetime and stage times', () {
      final record = CoolingRecord(
        id: 'r3',
        date: DateTime(2026, 9, 2),
        foodItemName: 'Cooked Rice',
        batchNo: 'B1',
        coolingStart: DateTime(2026, 9, 2, 12, 0),
        initialTempF: 170,
        initialTempInitials: 'AB',
        stage1Time: const DayTime(14, 0),
        stage1TempF: 68,
        stage1Initials: 'NL',
        stage2Time: const DayTime(17, 0),
        stage2TempF: 40,
        stage2Initials: 'JS',
        correctiveAction: '',
        initials: 'NL',
      );
      final restored = CoolingRecord.fromMap('r3', record.toMap());
      expect(restored.coolingStart, DateTime(2026, 9, 2, 12, 0));
      expect(restored.initialTempInitials, 'AB');
      expect(restored.stage1Time, const DayTime(14, 0));
      expect(restored.stage1Initials, 'NL');
      expect(restored.stage2TempF, 40);
      expect(restored.stage2Initials, 'JS');
      expect(restored.correctiveActionLabel, 'None');
    });
  });

  group('RiceHotHoldRecord', () {
    test('always exposes one check per fixed offset, even from a partial doc', () {
      final record = RiceHotHoldRecord.fromMap('r4', {
        'logType': 'riceHotHold',
        'dateMillis': DateTime(2026, 9, 3).millisecondsSinceEpoch,
        'checks': [
          {'hourOffset': 4, 'timeMin': 840, 'tempF': 150, 'initials': 'NL'},
        ],
      });
      expect(record.checks.map((c) => c.hourOffset).toList(), riceHotHoldOffsets);
      expect(record.checkAt(4).tempF, 150);
      expect(record.checkAt(2).tempF, isNull);
    });

    test('round-trips all three checks (+2/+4/+6, no +8)', () {
      expect(riceHotHoldOffsets, [2, 4, 6]);
      final record = RiceHotHoldRecord(
        id: 'r5',
        date: DateTime(2026, 9, 3),
        foodItemName: 'Sushi Rice',
        start: DateTime(2026, 9, 3, 12, 0),
        actualTempF: 170,
        startInitials: 'NL',
        checks: [
          for (final h in riceHotHoldOffsets)
            RiceHotHoldCheck(hourOffset: h, tempF: 150 + h.toDouble(), initials: 'NL'),
        ],
      );
      final restored = RiceHotHoldRecord.fromMap('r5', record.toMap());
      expect(restored.checks, hasLength(3));
      expect(restored.checkAt(6).tempF, 156);
      expect(restored.start, DateTime(2026, 9, 3, 12, 0));
      expect(restored.startInitials, 'NL');
    });

    test('round-trips finishedTime and discardTime', () {
      final record = RiceHotHoldRecord(
        id: 'r6',
        date: DateTime(2026, 9, 3),
        finishedTime: const DayTime(20, 0),
        discardTime: const DayTime(20, 30),
      );
      final restored = RiceHotHoldRecord.fromMap('r6', record.toMap());
      expect(restored.finishedTime, const DayTime(20, 0));
      expect(restored.discardTime, const DayTime(20, 30));
    });

    test('finishedTime/discardTime default to unset', () {
      final record = RiceHotHoldRecord(id: '', date: DateTime(2026, 9, 3));
      expect(record.finishedTime, isNull);
      expect(record.discardTime, isNull);
      expect(record.toMap().containsKey('finishedTimeMin'), isFalse);
      expect(record.toMap().containsKey('discardTimeMin'), isFalse);
    });
  });
}
