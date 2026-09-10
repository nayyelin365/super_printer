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
        locationId: 'loc1',
        locationName: "Bassett's Market",
        phMeterCalibrated: true,
        riceBatchNo: 'Batch-2026-0002',
        timeStartCooking: const DayTime(8, 0),
        timeCooked: const DayTime(8, 40),
        timeAcidified: const DayTime(9, 0),
        ricePh: 4.1,
        inRange: true,
        phAfterCorrected: 4.0,
        amountAddingVinegar: '50 ml',
        inRangeAfterCorrection: true,
        discardOutOfRangeRice: false,
        timeRiceAllUsed: const DayTime(15, 30),
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
      expect(restored.timeRiceAllUsed, const DayTime(15, 30));
      expect(restored.initials, 'NL');
      expect(restored.createdAt, DateTime.fromMillisecondsSinceEpoch(1000));
    });

    test('omits null optional times from the stored map', () {
      final record = SushiRicePhRecord(
        id: '',
        date: DateTime(2026, 8, 23),
        locationId: 'l',
        locationName: 'x',
      );
      final map = record.toMap();
      expect(map.containsKey('timeStartCookingMin'), isFalse);
      expect(map.containsKey('ricePh'), isFalse);
    });
  });

  group('SushiBarTempRecord', () {
    test('round-trips including the time slot enum', () {
      final record = SushiBarTempRecord(
        id: 'r2',
        date: DateTime(2026, 9, 1),
        locationId: 'l',
        locationName: "Miller's Market",
        timeSlot: TempTimeSlot.threePm,
        displayCaseTempF: 38,
        coolerTempF: 40,
        freezerTempF: 5,
        calibrated: true,
        initials: 'AB',
      );
      final restored = SushiBarTempRecord.fromMap('r2', record.toMap());
      expect(restored.timeSlot, TempTimeSlot.threePm);
      expect(restored.displayCaseTempF, 38);
      expect(restored.freezerTempF, 5);
      expect(restored.calibrated, true);
      expect(restored.timeSortKey, 15 * 60);
    });
  });

  group('CoolingRecord', () {
    test('round-trips the cooling-start datetime and stage times', () {
      final record = CoolingRecord(
        id: 'r3',
        date: DateTime(2026, 9, 2),
        locationId: 'l',
        locationName: 'x',
        foodItemName: 'Cooked Rice',
        batchNo: 'B1',
        coolingStart: DateTime(2026, 9, 2, 12, 0),
        initialTempF: 170,
        stage1Time: const DayTime(14, 0),
        stage1TempF: 68,
        stage2Time: const DayTime(17, 0),
        stage2TempF: 40,
        correctiveAction: '',
        initials: 'NL',
      );
      final restored = CoolingRecord.fromMap('r3', record.toMap());
      expect(restored.coolingStart, DateTime(2026, 9, 2, 12, 0));
      expect(restored.stage1Time, const DayTime(14, 0));
      expect(restored.stage2TempF, 40);
      expect(restored.correctiveActionLabel, 'None');
    });
  });

  group('RiceHotHoldRecord', () {
    test('always exposes one check per fixed offset, even from a partial doc', () {
      final record = RiceHotHoldRecord.fromMap('r4', {
        'logType': 'riceHotHold',
        'dateMillis': DateTime(2026, 9, 3).millisecondsSinceEpoch,
        'locationId': 'l',
        'locationName': 'x',
        'checks': [
          {'hourOffset': 4, 'timeMin': 840, 'tempF': 150, 'initials': 'NL'},
        ],
      });
      expect(record.checks.map((c) => c.hourOffset).toList(), riceHotHoldOffsets);
      expect(record.checkAt(4).tempF, 150);
      expect(record.checkAt(2).tempF, isNull);
    });

    test('round-trips all four checks', () {
      final record = RiceHotHoldRecord(
        id: 'r5',
        date: DateTime(2026, 9, 3),
        locationId: 'l',
        locationName: 'x',
        foodItemName: 'Sushi Rice',
        start: DateTime(2026, 9, 3, 12, 0),
        actualTempF: 170,
        checks: [
          for (final h in riceHotHoldOffsets)
            RiceHotHoldCheck(hourOffset: h, tempF: 150 + h.toDouble(), initials: 'NL'),
        ],
      );
      final restored = RiceHotHoldRecord.fromMap('r5', record.toMap());
      expect(restored.checkAt(8).tempF, 158);
      expect(restored.start, DateTime(2026, 9, 3, 12, 0));
    });
  });
}
