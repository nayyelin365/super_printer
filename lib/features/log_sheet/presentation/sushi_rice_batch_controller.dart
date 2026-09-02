import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sushi_rice_batch_repository.dart';
import '../data/sushi_rice_label_printer.dart';
import '../data/sushi_rice_notifications.dart';
import '../domain/sushi_rice_batch.dart';

final sushiRiceBatchRepositoryProvider = Provider<SushiRiceBatchRepository>(
  (ref) => SushiRiceBatchRepository(),
);

/// Every batch not yet finished/discarded — drives the Sushi Rice
/// Preparation dashboard's stage cards and batch list.
final activeSushiRiceBatchesProvider = StreamProvider<List<SushiRiceBatch>>((ref) {
  return ref.watch(sushiRiceBatchRepositoryProvider).watchActive();
});

/// Every batch ever created (including finished/discarded ones) — drives
/// the "Sushi Rice pH Log Sheet" HACCP report, which is a historical
/// record, not a work queue.
final allSushiRiceBatchesProvider = StreamProvider<List<SushiRiceBatch>>((ref) {
  return ref.watch(sushiRiceBatchRepositoryProvider).watchAll();
});

/// One batch by id — drives the batch detail screen.
final sushiRiceBatchProvider = StreamProvider.family<SushiRiceBatch?, String>((ref, batchId) {
  return ref.watch(sushiRiceBatchRepositoryProvider).watchOne(batchId);
});

class SushiRiceStartResult {
  const SushiRiceStartResult({required this.batch, required this.labelPrinted, this.printError});
  final SushiRiceBatch batch;
  final bool labelPrinted;
  final String? printError;
}

/// Outcome of [SushiRiceBatchController.submitPhReading] — the screen
/// decides what to show next from this rather than re-deriving it from
/// batch state.
enum PhOutcome { passedAndLabelPrinted, passedButPrintFailed, failed }

class SushiRiceBatchController {
  SushiRiceBatchController(this._ref);

  final Ref _ref;

  SushiRiceBatchRepository get _repository => _ref.read(sushiRiceBatchRepositoryProvider);

  /// Creates the batch, then immediately attempts "Save & Print" — the
  /// label prints at batch creation (Soaking start), not after a later
  /// verification step. Printer failures don't block starting the batch;
  /// the caller decides whether to prompt a retry. Soaking is always a
  /// fixed [sushiRiceSoakTotalMinutes] countdown, not a staff-chosen
  /// duration — see the constant's doc comment.
  Future<SushiRiceStartResult> startBatch({
    required double riceWeightLbs,
    required bool ricePotSanitized,
    required bool riceInspectedWashed,
    required bool enzymeAdded,
    required String soakingMethod,
    required String staffId,
    required String staffName,
    required String foodName,
    required String locationId,
    required String locationName,
  }) async {
    final now = DateTime.now();
    var batch = await _repository.create(
      SushiRiceBatch(
        id: '',
        batchCode: '',
        stage: SushiRiceStage.soaking,
        riceWeightLbs: riceWeightLbs,
        ricePotSanitized: ricePotSanitized,
        riceInspectedWashed: riceInspectedWashed,
        enzymeAdded: enzymeAdded,
        soakingMethod: soakingMethod,
        soakMinutes: sushiRiceSoakTotalMinutes,
        soakStartedAt: now,
        staffId: staffId,
        staffName: staffName,
        foodName: foodName,
        locationId: locationId,
        locationName: locationName,
      ),
    );

    await scheduleStageDoneAlert(
      batchId: batch.id,
      stage: SushiRiceStage.soaking,
      title: "Soaking Time's Up!",
      body: 'Sushi Rice soaking time has finished. Please proceed to the next step.',
      at: now.add(const Duration(minutes: sushiRiceSoakTotalMinutes)),
    );

    final printResult = await printSushiRiceBatchLabel(
      _ref,
      batchCode: batch.batchCode,
      prepDateTime: now,
      soakEndsAt: batch.soakEndsAt,
      employeeName: staffName,
    );

    if (printResult.success) {
      batch = batch.copyWith(labelPrinted: true);
      await _repository.update(batch);
    }

    return SushiRiceStartResult(
      batch: batch,
      labelPrinted: printResult.success,
      printError: printResult.errorMessage,
    );
  }

  /// Retries the "Save & Print" label after a printer failure.
  Future<SushiRiceStartResult> retryLabelPrint(SushiRiceBatch batch) async {
    final printResult = await printSushiRiceBatchLabel(
      _ref,
      batchCode: batch.batchCode,
      prepDateTime: batch.soakStartedAt ?? DateTime.now(),
      soakEndsAt: batch.soakEndsAt,
      employeeName: batch.staffName ?? '',
    );
    var updated = batch;
    if (printResult.success) {
      updated = batch.copyWith(labelPrinted: true);
      await _repository.update(updated);
    }
    return SushiRiceStartResult(
      batch: updated,
      labelPrinted: printResult.success,
      printError: printResult.errorMessage,
    );
  }

  /// Confirms "Start Cooking" — staff pick/enter who is starting this step
  /// again (not carried over from Soaking's staff), moving the batch into
  /// a fixed [sushiRiceCookRestTotalMinutes] Cooking & Rest countdown.
  Future<void> startCooking(
    SushiRiceBatch batch, {
    required String staffId,
    required String staffName,
  }) async {
    await cancelStageDoneAlert(batch.id, SushiRiceStage.soaking);
    final now = DateTime.now();
    await _repository.update(
      batch.copyWith(
        stage: SushiRiceStage.cookingRest,
        cookRestMinutes: () => sushiRiceCookRestTotalMinutes,
        cookRestStartedAt: () => now,
        cookRestStaffId: () => staffId,
        cookRestStaffName: () => staffName,
      ),
    );
    await scheduleStageDoneAlert(
      batchId: batch.id,
      stage: SushiRiceStage.cookingRest,
      title: "Cooking & Rest Time's Up!",
      body: 'Cook & Rest has finished. Please mix seasoning vinegar and cool the rice.',
      at: now.add(const Duration(minutes: sushiRiceCookRestTotalMinutes)),
    );
  }

  /// Confirms "Start Mixing" — vinegar amount + staff chosen again, moving
  /// the batch into a fixed [sushiRiceMixCoolTotalMinutes] Mixing & Cooling
  /// countdown.
  Future<void> startMixing(
    SushiRiceBatch batch, {
    required double vinegarAmountOz,
    required String staffId,
    required String staffName,
  }) async {
    await cancelStageDoneAlert(batch.id, SushiRiceStage.cookingRest);
    final now = DateTime.now();
    await _repository.update(
      batch.copyWith(
        stage: SushiRiceStage.mixingCooling,
        vinegarAmountOz: () => vinegarAmountOz,
        mixCoolMinutes: () => sushiRiceMixCoolTotalMinutes,
        mixCoolStartedAt: () => now,
        mixCoolStaffId: () => staffId,
        mixCoolStaffName: () => staffName,
      ),
    );
    await scheduleStageDoneAlert(
      batchId: batch.id,
      stage: SushiRiceStage.mixingCooling,
      title: "Mixing & Cooling Time's Up!",
      body: 'Mixing & Cooling has finished. Please measure the pH level.',
      at: now.add(const Duration(minutes: sushiRiceMixCoolTotalMinutes)),
    );
  }

  /// Confirms "Measure pH Level" — staff chosen again, moving the batch
  /// into pH Check.
  Future<void> startPhCheck(
    SushiRiceBatch batch, {
    required String staffId,
    required String staffName,
  }) async {
    await cancelStageDoneAlert(batch.id, SushiRiceStage.mixingCooling);
    await _repository.update(
      batch.copyWith(
        stage: SushiRiceStage.phCheck,
        phCheckStaffId: () => staffId,
        phCheckStaffName: () => staffName,
      ),
    );
  }

  /// Records a pH reading. A pass (<= [sushiRicePhPassThreshold]) attempts
  /// the auto-print of the 24-Hr TPHC label; on success it starts Ready to
  /// Use. A fail leaves the batch in pH Check for a retest — the screen
  /// shows the corrective-action prompt and calls [recordCorrectiveRetest]
  /// with the next reading.
  Future<PhOutcome> submitPhReading(SushiRiceBatch batch, double reading) async {
    final now = DateTime.now();
    final updated = batch.copyWith(phReading: () => reading, phReadingAt: () => now);
    await _repository.update(updated);

    if (!updated.phPassed) return PhOutcome.failed;
    return _printTphcLabelAndStartReadyToUse(updated);
  }

  /// Records a retest reading after [PhOutcome.failed] — same as
  /// [submitPhReading] but also marks corrective action as taken (with the
  /// same staff who's running the pH check).
  Future<PhOutcome> recordCorrectiveRetest(SushiRiceBatch batch, double reading) async {
    final now = DateTime.now();
    final updated = batch.copyWith(
      phReading: () => reading,
      phReadingAt: () => now,
      correctiveActionTaken: true,
      correctiveActionTakenAt: () => now,
      correctivePhValue: () => reading,
    );
    await _repository.update(updated);

    if (!updated.phPassed) return PhOutcome.failed;
    return _printTphcLabelAndStartReadyToUse(updated);
  }

  /// Retries the TPHC label print after [PhOutcome.passedButPrintFailed] —
  /// same batch, same reading, no need to re-measure pH.
  Future<PhOutcome> retryTphcLabelPrint(SushiRiceBatch batch) =>
      _printTphcLabelAndStartReadyToUse(batch);

  Future<PhOutcome> _printTphcLabelAndStartReadyToUse(SushiRiceBatch batch) async {
    final now = DateTime.now();
    final deadline = now.add(const Duration(hours: sushiRiceReadyToUseWindowHours));
    final printResult = await printSushiRiceTphcLabel(
      _ref,
      batchCode: batch.batchCode,
      phReading: batch.phReading ?? 0,
      prepDateTime: now,
      useBy: deadline,
      employeeName: batch.phCheckStaffName ?? '',
    );
    if (!printResult.success) return PhOutcome.passedButPrintFailed;

    final withLabel = batch.copyWith(
      labelPrinted: true,
      stage: SushiRiceStage.readyToUse,
      readyToUseStartedAt: () => now,
    );
    await _repository.update(withLabel);
    await scheduleTphcAlerts(batch.id, now);
    return PhOutcome.passedAndLabelPrinted;
  }

  Future<void> acknowledgeHour(SushiRiceBatch batch, int hourIndex) async {
    final hour = sushiRiceTphcAlertHours[hourIndex];
    await _repository.update(batch.copyWith(lastAcknowledgedHour: () => hour));
  }

  /// "Finish Batch" — records the final outcome (Used/Discarded/Expired)
  /// and who recorded it, cancels every pending alert, and excludes the
  /// batch from the active dashboard (it still appears on the HACCP log
  /// sheet report).
  Future<void> setFinalBatchStatus(
    SushiRiceBatch batch, {
    required String status,
    required String staffId,
    required String staffName,
  }) async {
    await cancelAllStageAlerts(batch.id);
    await cancelTphcAlerts(batch.id);
    await _repository.update(
      batch.copyWith(
        finalBatchStatus: () => status,
        finalStatusStaffId: () => staffId,
        finalStatusStaffName: () => staffName,
        finishedAt: () => DateTime.now(),
      ),
    );
  }
}

final sushiRiceBatchControllerProvider = Provider<SushiRiceBatchController>(
  (ref) => SushiRiceBatchController(ref),
);
