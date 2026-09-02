import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/log_sheet/domain/sushi_rice_batch.dart';

void main() {
  group('SushiRiceBatch', () {
    test('soakEndsAt is soakStartedAt + soakMinutes', () {
      final batch = SushiRiceBatch(
        id: 'b1',
        batchCode: 'Batch-2026-0001',
        stage: SushiRiceStage.soaking,
        soakStartedAt: DateTime(2026, 1, 1, 9),
        soakMinutes: 25,
      );
      expect(batch.soakEndsAt, DateTime(2026, 1, 1, 9, 25));
    });

    test('soakEndsAt is null when soak hasn\'t started or has no duration', () {
      const noStart = SushiRiceBatch(
        id: 'b1',
        batchCode: 'Batch-2026-0001',
        stage: SushiRiceStage.soaking,
        soakMinutes: 25,
      );
      expect(noStart.soakEndsAt, isNull);

      final noMinutes = SushiRiceBatch(
        id: 'b1',
        batchCode: 'Batch-2026-0001',
        stage: SushiRiceStage.soaking,
        soakStartedAt: DateTime(2026, 1, 1, 9),
      );
      expect(noMinutes.soakEndsAt, isNull);
    });

    test('toMap/fromMap round-trip preserves every field', () {
      final batch = SushiRiceBatch(
        id: 'batch-1',
        batchCode: 'Batch-2026-0002',
        stage: SushiRiceStage.soaking,
        riceWeightLbs: 6,
        ricePotSanitized: true,
        riceInspectedWashed: true,
        enzymeAdded: false,
        soakMinutes: 25,
        soakStartedAt: DateTime(2026, 1, 1, 9),
        staffId: 'staff1',
        staffName: 'Jhon Doe',
        labelPrinted: true,
        foodName: 'Sushi Rice',
        locationId: 'loc1',
        locationName: 'Walk-in Cooler',
      );

      final restored = SushiRiceBatch.fromMap('batch-1', batch.toMap());

      expect(restored.id, batch.id);
      expect(restored.batchCode, batch.batchCode);
      expect(restored.stage, batch.stage);
      expect(restored.riceWeightLbs, batch.riceWeightLbs);
      expect(restored.ricePotSanitized, batch.ricePotSanitized);
      expect(restored.riceInspectedWashed, batch.riceInspectedWashed);
      expect(restored.enzymeAdded, batch.enzymeAdded);
      expect(restored.soakMinutes, batch.soakMinutes);
      expect(restored.soakStartedAt, batch.soakStartedAt);
      expect(restored.staffId, batch.staffId);
      expect(restored.staffName, batch.staffName);
      expect(restored.labelPrinted, batch.labelPrinted);
      expect(restored.foodName, batch.foodName);
      expect(restored.locationId, batch.locationId);
      expect(restored.locationName, batch.locationName);
    });

    test('copyWith updates only the requested fields', () {
      const batch = SushiRiceBatch(
        id: 'b1',
        batchCode: 'Batch-2026-0001',
        stage: SushiRiceStage.soaking,
        soakMinutes: 25,
      );
      final updated = batch.copyWith(labelPrinted: true);

      expect(updated.labelPrinted, isTrue);
      expect(updated.soakMinutes, 25, reason: 'unspecified fields must be preserved');
    });

    test('cookRestEndsAt and mixCoolEndsAt mirror soakEndsAt', () {
      final batch = SushiRiceBatch(
        id: 'b1',
        batchCode: 'Batch-2026-0001',
        stage: SushiRiceStage.mixingCooling,
        cookRestStartedAt: DateTime(2026, 1, 1, 10),
        cookRestMinutes: 50,
        mixCoolStartedAt: DateTime(2026, 1, 1, 11),
        mixCoolMinutes: 35,
      );
      expect(batch.cookRestEndsAt, DateTime(2026, 1, 1, 10, 50));
      expect(batch.mixCoolEndsAt, DateTime(2026, 1, 1, 11, 35));
    });

    test('startCooking/startMixing/startPhCheck fields round-trip through toMap/fromMap', () {
      final batch = SushiRiceBatch(
        id: 'b1',
        batchCode: 'Batch-2026-0001',
        stage: SushiRiceStage.phCheck,
        cookRestMinutes: 50,
        cookRestStartedAt: DateTime(2026, 1, 1, 10),
        cookRestStaffId: 'staff2',
        cookRestStaffName: 'Dave M',
        vinegarAmountOz: 8,
        mixCoolMinutes: 35,
        mixCoolStartedAt: DateTime(2026, 1, 1, 11),
        mixCoolStaffId: 'staff3',
        mixCoolStaffName: 'Taylar S',
        phCheckStaffId: 'staff4',
        phCheckStaffName: 'Mark M',
      );

      final restored = SushiRiceBatch.fromMap('b1', batch.toMap());

      expect(restored.cookRestMinutes, 50);
      expect(restored.cookRestStaffName, 'Dave M');
      expect(restored.vinegarAmountOz, 8);
      expect(restored.mixCoolStaffName, 'Taylar S');
      expect(restored.phCheckStaffName, 'Mark M');
    });

    test('phPassed uses the 4.2 critical limit', () {
      SushiRiceBatch withPh(double? ph) => SushiRiceBatch(
        id: 'b1',
        batchCode: 'Batch-2026-0001',
        stage: SushiRiceStage.phCheck,
        phReading: ph,
      );

      expect(withPh(4.2).phPassed, isTrue);
      expect(withPh(4.1).phPassed, isTrue);
      expect(withPh(4.3).phPassed, isFalse);
      expect(withPh(4.7).phPassed, isFalse);
      expect(withPh(null).phPassed, isFalse);
    });

    test('readyToUseDeadline is 24 hours after readyToUseStartedAt', () {
      final batch = SushiRiceBatch(
        id: 'b1',
        batchCode: 'Batch-2026-0001',
        stage: SushiRiceStage.readyToUse,
        readyToUseStartedAt: DateTime(2026, 1, 1, 10),
      );
      expect(batch.readyToUseDeadline, DateTime(2026, 1, 2, 10));
    });

    test('pH check, corrective action, and final status fields round-trip', () {
      final batch = SushiRiceBatch(
        id: 'b1',
        batchCode: 'Batch-2026-0001',
        stage: SushiRiceStage.readyToUse,
        phReading: 4.7,
        phReadingAt: DateTime(2026, 1, 1, 10),
        correctiveActionTaken: true,
        correctiveActionTakenAt: DateTime(2026, 1, 1, 10, 5),
        correctivePhValue: 4.1,
        readyToUseStartedAt: DateTime(2026, 1, 1, 10, 10),
        lastAcknowledgedHour: 20,
        finalBatchStatus: 'Used',
        finalStatusStaffId: 'staff5',
        finalStatusStaffName: 'T.Y.',
        finishedAt: DateTime(2026, 1, 2, 8),
      );

      final restored = SushiRiceBatch.fromMap('b1', batch.toMap());

      expect(restored.phReading, 4.7);
      expect(restored.phReadingAt, DateTime(2026, 1, 1, 10));
      expect(restored.correctiveActionTaken, isTrue);
      expect(restored.correctiveActionTakenAt, DateTime(2026, 1, 1, 10, 5));
      expect(restored.correctivePhValue, 4.1);
      expect(restored.readyToUseStartedAt, DateTime(2026, 1, 1, 10, 10));
      expect(restored.lastAcknowledgedHour, 20);
      expect(restored.finalBatchStatus, 'Used');
      expect(restored.finalStatusStaffName, 'T.Y.');
      expect(restored.finishedAt, DateTime(2026, 1, 2, 8));
    });
  });
}
