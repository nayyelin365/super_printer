import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alarm/presentation/alarm_controller.dart';
import '../data/sushi_rice_batch_repository.dart';
import '../data/sushi_rice_label_printer.dart';
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
  const SushiRiceStartResult({
    required this.batch,
    required this.labelPrinted,
    this.printError,
    this.alarmPermissionGranted = true,
  });
  final SushiRiceBatch batch;
  final bool labelPrinted;
  final String? printError;

  /// False if the OS denied notification/exact-alarm permission when the
  /// Soaking buzzer was scheduled — the caller should warn that this
  /// batch's alerts may not fire, same as the plain Alarm editor does.
  /// Only checked once, at batch creation: permission granted for the
  /// first alarm stays granted for the rest of the batch's alarms.
  final bool alarmPermissionGranted;
}

/// Outcome of [SushiRiceBatchController.submitPhReading] — the screen
/// decides what to show next from this rather than re-deriving it from
/// batch state.
enum PhOutcome { passedAndLabelPrinted, passedButPrintFailed, failed }

class SushiRiceBatchController {
  SushiRiceBatchController(this._ref);

  final Ref _ref;

  SushiRiceBatchRepository get _repository => _ref.read(sushiRiceBatchRepositoryProvider);

  /// Looks up a batch by its printed `batchCode` — what "Scan QR on Label"
  /// actually scans off a batch label, not the Firestore doc id.
  Future<SushiRiceBatch?> findByBatchCode(String batchCode) => _repository.findByBatchCode(batchCode);

  /// Every "... Time's Up!" buzzer and TPHC compliance alert this SOP
  /// raises is a real entry in the app's existing Alarm system (the same
  /// one the Alarms tab shows and rings) rather than a separate
  /// notification channel — so a batch's pending alerts are always
  /// visible there too, and get the Alarm feature's own reliability
  /// (proper alarm audio stream, full-screen intent, Dismiss/Snooze).
  Future<String> _scheduleAlarm({required DateTime at, required String title}) async {
    final alarm = await _ref
        .read(alarmControllerProvider.notifier)
        .addAlarm(hour: at.hour, minute: at.minute, title: title, repeatSound: true);
    return alarm.id;
  }

  /// Requests notification/exact-alarm permission — same call the plain
  /// Alarm editor makes before its first `addAlarm`. Idempotent (a no-op
  /// once already granted), so it's safe to call again on every batch even
  /// though the caller only actually surfaces the result at creation time.
  Future<bool> _ensureAlarmPermissions() =>
      _ref.read(alarmControllerProvider.notifier).ensurePermissions();

  Future<void> _cancelAlarm(String? alarmId) async {
    if (alarmId == null) return;
    await _ref.read(alarmControllerProvider.notifier).deleteAlarm(alarmId);
  }

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
    String? foodName,
    String? locationId,
    String? locationName,
  }) async {
    final permissionGranted = await _ensureAlarmPermissions();

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

    final alarmId = await _scheduleAlarm(
      at: now.add(const Duration(minutes: sushiRiceSoakTotalMinutes)),
      title: '${batch.batchCode} — Start Cooking',
    );
    batch = batch.copyWith(currentStageAlarmId: () => alarmId);
    await _repository.update(batch);

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
      alarmPermissionGranted: permissionGranted,
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
    await _cancelAlarm(batch.currentStageAlarmId);
    final now = DateTime.now();
    final alarmId = await _scheduleAlarm(
      at: now.add(const Duration(minutes: sushiRiceCookRestTotalMinutes)),
      title: '${batch.batchCode} — Mix Seasoning Vinegar',
    );
    await _repository.update(
      batch.copyWith(
        stage: SushiRiceStage.cookingRest,
        cookRestMinutes: () => sushiRiceCookRestTotalMinutes,
        cookRestStartedAt: () => now,
        cookRestStaffId: () => staffId,
        cookRestStaffName: () => staffName,
        currentStageAlarmId: () => alarmId,
      ),
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
    await _cancelAlarm(batch.currentStageAlarmId);
    final now = DateTime.now();
    final alarmId = await _scheduleAlarm(
      at: now.add(const Duration(minutes: sushiRiceMixCoolTotalMinutes)),
      title: '${batch.batchCode} — Test pH Level',
    );
    await _repository.update(
      batch.copyWith(
        stage: SushiRiceStage.mixingCooling,
        vinegarAmountOz: () => vinegarAmountOz,
        mixCoolMinutes: () => sushiRiceMixCoolTotalMinutes,
        mixCoolStartedAt: () => now,
        mixCoolStaffId: () => staffId,
        mixCoolStaffName: () => staffName,
        currentStageAlarmId: () => alarmId,
      ),
    );
  }

  /// Confirms "Measure pH Level" — staff chosen again, moving the batch
  /// into pH Check. Starts its own 30-min window
  /// ([SushiRiceBatch.phCheckEndsAt]) but no new alarm (no bespoke
  /// notification channel for this SOP) — just cancels Mixing & Cooling's.
  Future<void> startPhCheck(
    SushiRiceBatch batch, {
    required String staffId,
    required String staffName,
  }) async {
    await _cancelAlarm(batch.currentStageAlarmId);
    await _repository.update(
      batch.copyWith(
        stage: SushiRiceStage.phCheck,
        phCheckStartedAt: () => DateTime.now(),
        phCheckStaffId: () => staffId,
        phCheckStaffName: () => staffName,
        currentStageAlarmId: () => null,
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
  Future<PhOutcome> recordCorrectiveRetest(
    SushiRiceBatch batch,
    double reading, {
    required double vinegarAmountOz,
  }) async {
    final now = DateTime.now();
    final updated = batch.copyWith(
      phReading: () => reading,
      phReadingAt: () => now,
      correctiveActionTaken: true,
      correctiveActionTakenAt: () => now,
      correctivePhValue: () => reading,
      correctiveVinegarAmountOz: () => vinegarAmountOz,
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
    // The 24-hr shelf-life clock counts from when vinegar was added
    // (Mixing & Cooling's start), not from this exact pH-pass moment —
    // see `SushiRiceBatch.readyToUseDeadline`. Falls back to `now` only if
    // that's somehow missing, which shouldn't happen once pH Check has
    // been reached.
    final vinegarAddedAt = batch.mixCoolStartedAt ?? now;
    final deadline = vinegarAddedAt.add(const Duration(hours: sushiRiceReadyToUseWindowHours));
    final printResult = await printSushiRiceTphcLabel(
      _ref,
      batchCode: batch.batchCode,
      phReading: batch.phReading ?? 0,
      prepDateTime: now,
      useBy: deadline,
      employeeName: batch.phCheckStaffName ?? '',
    );
    if (!printResult.success) return PhOutcome.passedButPrintFailed;

    // One real Alarm per TPHC hour mark, each counted from the same
    // vinegar-added anchor as `deadline` above. Each keeps re-alerting
    // until dismissed (`repeatSound: true`) — the closest honest match to
    // "buzz every 5 minutes until Acknowledge" this app's notification
    // layer can actually do without native platform code (see the Alarm
    // feature's own documented "repeat sound" limitation); "Acknowledge"
    // in the TPHC screen deletes the alarm outright.
    final alarmIds = <String>[];
    for (final hour in sushiRiceTphcAlertHours) {
      final id = await _scheduleAlarm(
        at: vinegarAddedAt.add(Duration(hours: hour)),
        title: '${batch.batchCode} — TPHC Check ($hour hr)',
      );
      alarmIds.add(id);
    }

    final withLabel = batch.copyWith(
      labelPrinted: true,
      stage: SushiRiceStage.readyToUse,
      readyToUseStartedAt: () => now,
      tphcAlarmIds: alarmIds,
    );
    await _repository.update(withLabel);
    return PhOutcome.passedAndLabelPrinted;
  }

  Future<void> acknowledgeHour(SushiRiceBatch batch, int hourIndex) async {
    final hour = sushiRiceTphcAlertHours[hourIndex];
    if (hourIndex < batch.tphcAlarmIds.length) {
      await _cancelAlarm(batch.tphcAlarmIds[hourIndex]);
    }
    await _repository.update(batch.copyWith(lastAcknowledgedHour: () => hour));
  }

  /// "Finish Batch" — records the final outcome (Used/Discarded/Expired)
  /// and who recorded it, cancels every pending alarm, and excludes the
  /// batch from the active dashboard (it still appears on the HACCP log
  /// sheet report).
  Future<void> setFinalBatchStatus(
    SushiRiceBatch batch, {
    required String status,
    required String staffId,
    required String staffName,
    String? discardReason,
    String? discardRemark,
  }) async {
    await _cancelAlarm(batch.currentStageAlarmId);
    for (final alarmId in batch.tphcAlarmIds) {
      await _cancelAlarm(alarmId);
    }
    await _repository.update(
      batch.copyWith(
        finalBatchStatus: () => status,
        finalStatusStaffId: () => staffId,
        finalStatusStaffName: () => staffName,
        finishedAt: () => DateTime.now(),
        discardReason: () => discardReason,
        discardRemark: () => discardRemark,
      ),
    );
  }

  /// No server-side cron in this app, so "automatically discard after 24
  /// hours" means: check opportunistically whenever a batch is rendered
  /// (dashboard list, detail screen) and, the first time it's found past
  /// its Ready to Use deadline with no Finish Batch action yet, close it
  /// out as "Expired" — attributed to a system id since no one's acting.
  /// A no-op once [SushiRiceBatch.finishedAt] is set, so repeat calls
  /// across ticks/rebuilds are harmless.
  Future<void> autoExpireIfNeeded(SushiRiceBatch batch) async {
    if (batch.stage != SushiRiceStage.readyToUse || batch.finishedAt != null) return;
    final deadline = batch.readyToUseDeadline;
    if (deadline == null || !DateTime.now().isAfter(deadline)) return;
    await setFinalBatchStatus(
      batch,
      status: 'Expired',
      staffId: 'system',
      staffName: 'Auto (24hr expired)',
    );
  }
}

final sushiRiceBatchControllerProvider = Provider<SushiRiceBatchController>(
  (ref) => SushiRiceBatchController(ref),
);
