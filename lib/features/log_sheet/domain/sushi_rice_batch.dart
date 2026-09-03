/// The Sushi Rice SOP's five stages, in order — matches the "Sushi Rice
/// Preparation" dashboard's five cards.
enum SushiRiceStage {
  soaking,
  cookingRest,
  mixingCooling,
  phCheck,
  readyToUse,
}

/// Fixed weight of an empty rice pot, used to show "Pot + Rice" totals on
/// the rice-weight picker (e.g. 6 lbs rice -> 8.5 lbs pot + rice).
const sushiRicePotWeightLbs = 2.5;

/// The pH threshold a batch must be at or under to pass verification —
/// matches the printed HACCP log sheet's "Critical Limit: ≤ 4.2".
const sushiRicePhPassThreshold = 4.2;

/// Each timer stage is a fixed countdown, not a staff-chosen duration —
/// its "start next step" button stays disabled for the first `unlock`
/// minutes (the SOP's minimum time), then becomes available for the rest
/// of the window; if it's still not tapped by `total`, the "Time's Up!"
/// alert fires. Soak: 20–30 min. Cook & Rest: 45–50 min.
/// Mixing & Cooling: 25–35 min.
const sushiRiceSoakUnlockMinutes = 20;
const sushiRiceSoakTotalMinutes = 30;
const sushiRiceCookRestUnlockMinutes = 45;
const sushiRiceCookRestTotalMinutes = 50;
const sushiRiceMixCoolUnlockMinutes = 25;
const sushiRiceMixCoolTotalMinutes = 35;

/// Vinegar amounts offered when advancing Cooking & Rest -> Mixing &
/// Cooling.
const sushiRiceVinegarAmountsOz = [4.0, 8.0, 12.0];

/// How long a batch may sit in Ready to Use (TPHC — Time/Temperature
/// Control for Safety) before it must be discarded.
const sushiRiceReadyToUseWindowHours = 24;

/// The hour marks (since Ready to Use started) at which a compliance alert
/// fires, requiring staff to acknowledge it.
const sushiRiceTphcAlertHours = [20, 21, 22, 23, 24];

/// How often the "please acknowledge" reminder re-fires for the current
/// hour mark until it's acknowledged (or the batch is finished/discarded).
const sushiRiceTphcReminderInterval = Duration(minutes: 5);

/// Final outcome choices offered on Finish Batch, for "Stage 4: End of
/// Batch Record" on the HACCP log sheet.
const sushiRiceFinalStatuses = ['Used', 'Discarded', 'Expired'];

/// One Sushi Rice batch moving through the SOP — multiple can be in
/// progress at once (the dashboard tracks all of them), each identified by
/// a human-readable [batchCode] like "Batch-2026-0002" (see
/// `SushiRiceBatchRepository._nextBatchCode`). Every field here is exactly
/// what the "Sushi Rice pH Log Sheet" HACCP report renders — see
/// `SushiRicePhLogSheetScreen`.
class SushiRiceBatch {
  const SushiRiceBatch({
    required this.id,
    required this.batchCode,
    required this.stage,
    this.riceWeightLbs,
    this.ricePotSanitized = false,
    this.riceInspectedWashed = false,
    this.enzymeAdded = false,
    this.soakMinutes,
    this.soakStartedAt,
    this.staffId,
    this.staffName,
    this.cookRestMinutes,
    this.cookRestStartedAt,
    this.cookRestStaffId,
    this.cookRestStaffName,
    this.vinegarAmountOz,
    this.mixCoolMinutes,
    this.mixCoolStartedAt,
    this.mixCoolStaffId,
    this.mixCoolStaffName,
    this.phCheckStaffId,
    this.phCheckStaffName,
    this.phReading,
    this.phReadingAt,
    this.correctiveActionTaken = false,
    this.correctiveActionTakenAt,
    this.correctivePhValue,
    this.labelPrinted = false,
    this.readyToUseStartedAt,
    this.lastAcknowledgedHour,
    this.currentStageAlarmId,
    this.tphcAlarmIds = const [],
    this.finalBatchStatus,
    this.finalStatusStaffId,
    this.finalStatusStaffName,
    this.foodName,
    this.locationId,
    this.locationName,
    this.finishedAt,
  });

  /// Firestore document id — empty string for a batch not yet saved.
  final String id;

  final String batchCode;
  final SushiRiceStage stage;

  /// Rice-only weight chosen on the Soaking setup screen (e.g. 6, 3, 10) —
  /// the label/checklist also show `riceWeightLbs + sushiRicePotWeightLbs`
  /// as the "Pot + Rice" total.
  final double? riceWeightLbs;

  final bool ricePotSanitized;
  final bool riceInspectedWashed;
  final bool enzymeAdded;


  final int? soakMinutes;
  final DateTime? soakStartedAt;

  /// Who started this batch (chosen/typed on the Soaking setup screen).
  final String? staffId;
  final String? staffName;

  /// Who confirmed "Start Cooking" — chosen again at that moment, not
  /// carried over from Soaking's staff. `cookRestStartedAt` doubles as
  /// "Rice Cooking Started" on the log sheet.
  final int? cookRestMinutes;
  final DateTime? cookRestStartedAt;
  final String? cookRestStaffId;
  final String? cookRestStaffName;

  /// Chosen when confirming "Start Mixing" (Cooking & Rest -> Mixing &
  /// Cooling). `mixCoolStartedAt` doubles as both "Rice Cooking Finished"
  /// and "Vinegar Mixing Time" on the log sheet — they're the same moment.
  final double? vinegarAmountOz;
  final int? mixCoolMinutes;
  final DateTime? mixCoolStartedAt;
  final String? mixCoolStaffId;
  final String? mixCoolStaffName;

  /// Who confirmed "Measure pH Level" (Mixing & Cooling -> pH Check) — also
  /// the staff who takes the pH reading(s) below.
  final String? phCheckStaffId;
  final String? phCheckStaffName;

  /// The latest pH reading (a retest after [correctiveActionTaken]
  /// overwrites this with the new value) and when it was taken.
  final double? phReading;
  final DateTime? phReadingAt;

  /// Set once a reading has failed (> [sushiRicePhPassThreshold]) and the
  /// batch is retested — [correctivePhValue] is the passing retest value.
  final bool correctiveActionTaken;
  final DateTime? correctiveActionTakenAt;
  final double? correctivePhValue;

  /// Printed at "Save & Print" — once at batch creation (Soaking start)
  /// and again at the pH-pass 24-Hr TPHC label.
  final bool labelPrinted;

  /// Set once the pH-pass label prints — the anchor for every TPHC hour
  /// mark and the Ready to Use countdown ("Ready for Use Time" /
  /// "Calculated Expiration Time" on the log sheet).
  final DateTime? readyToUseStartedAt;

  /// The highest [sushiRiceTphcAlertHours] entry acknowledged so far, or
  /// null if none yet.
  final int? lastAcknowledgedHour;

  /// The real Alarm-feature alarm id for whatever "... Time's Up!" buzzer
  /// is currently pending for this batch's Soaking/Cooking & Rest/Mixing &
  /// Cooling stage — every automatic alert this SOP raises goes through
  /// the same Alarm system the Alarms tab shows/rings, not a bespoke
  /// notification channel. Cancelled and replaced on every stage
  /// transition; see `SushiRiceBatchController`.
  final String? currentStageAlarmId;

  /// The Alarm ids for the five TPHC hour-mark alerts (see
  /// [sushiRiceTphcAlertHours]), same index order — cancelled individually
  /// as each is acknowledged, and in bulk on Finish Batch.
  final List<String> tphcAlarmIds;

  /// "Stage 4: End of Batch Record" — set on Finish Batch.
  final String? finalBatchStatus;
  final String? finalStatusStaffId;
  final String? finalStatusStaffName;

  final String? foodName;
  final String? locationId;
  final String? locationName;

  /// Set once the batch is finished/discarded — batches with this set are
  /// excluded from the active dashboard list, but still appear on the
  /// HACCP log sheet report.
  final DateTime? finishedAt;

  bool get phPassed => phReading != null && phReading! <= sushiRicePhPassThreshold;

  DateTime? get soakEndsAt =>
      soakStartedAt != null && soakMinutes != null
          ? soakStartedAt!.add(Duration(minutes: soakMinutes!))
          : null;

  DateTime? get cookRestEndsAt =>
      cookRestStartedAt != null && cookRestMinutes != null
          ? cookRestStartedAt!.add(Duration(minutes: cookRestMinutes!))
          : null;

  DateTime? get mixCoolEndsAt =>
      mixCoolStartedAt != null && mixCoolMinutes != null
          ? mixCoolStartedAt!.add(Duration(minutes: mixCoolMinutes!))
          : null;

  DateTime? get readyToUseDeadline =>
      readyToUseStartedAt?.add(const Duration(hours: sushiRiceReadyToUseWindowHours));

  SushiRiceBatch copyWith({
    SushiRiceStage? stage,
    double? Function()? riceWeightLbs,
    bool? ricePotSanitized,
    bool? riceInspectedWashed,
    bool? enzymeAdded,
    int? Function()? soakMinutes,
    DateTime? Function()? soakStartedAt,
    String? Function()? staffId,
    String? Function()? staffName,
    int? Function()? cookRestMinutes,
    DateTime? Function()? cookRestStartedAt,
    String? Function()? cookRestStaffId,
    String? Function()? cookRestStaffName,
    double? Function()? vinegarAmountOz,
    int? Function()? mixCoolMinutes,
    DateTime? Function()? mixCoolStartedAt,
    String? Function()? mixCoolStaffId,
    String? Function()? mixCoolStaffName,
    String? Function()? phCheckStaffId,
    String? Function()? phCheckStaffName,
    double? Function()? phReading,
    DateTime? Function()? phReadingAt,
    bool? correctiveActionTaken,
    DateTime? Function()? correctiveActionTakenAt,
    double? Function()? correctivePhValue,
    bool? labelPrinted,
    DateTime? Function()? readyToUseStartedAt,
    int? Function()? lastAcknowledgedHour,
    String? Function()? currentStageAlarmId,
    List<String>? tphcAlarmIds,
    String? Function()? finalBatchStatus,
    String? Function()? finalStatusStaffId,
    String? Function()? finalStatusStaffName,
    String? foodName,
    String? locationId,
    String? locationName,
    DateTime? Function()? finishedAt,
  }) {
    return SushiRiceBatch(
      id: id,
      batchCode: batchCode,
      stage: stage ?? this.stage,
      riceWeightLbs: riceWeightLbs != null ? riceWeightLbs() : this.riceWeightLbs,
      ricePotSanitized: ricePotSanitized ?? this.ricePotSanitized,
      riceInspectedWashed: riceInspectedWashed ?? this.riceInspectedWashed,
      enzymeAdded: enzymeAdded ?? this.enzymeAdded,
      soakMinutes: soakMinutes != null ? soakMinutes() : this.soakMinutes,
      soakStartedAt: soakStartedAt != null ? soakStartedAt() : this.soakStartedAt,
      staffId: staffId != null ? staffId() : this.staffId,
      staffName: staffName != null ? staffName() : this.staffName,
      cookRestMinutes: cookRestMinutes != null ? cookRestMinutes() : this.cookRestMinutes,
      cookRestStartedAt: cookRestStartedAt != null ? cookRestStartedAt() : this.cookRestStartedAt,
      cookRestStaffId: cookRestStaffId != null ? cookRestStaffId() : this.cookRestStaffId,
      cookRestStaffName: cookRestStaffName != null ? cookRestStaffName() : this.cookRestStaffName,
      vinegarAmountOz: vinegarAmountOz != null ? vinegarAmountOz() : this.vinegarAmountOz,
      mixCoolMinutes: mixCoolMinutes != null ? mixCoolMinutes() : this.mixCoolMinutes,
      mixCoolStartedAt: mixCoolStartedAt != null ? mixCoolStartedAt() : this.mixCoolStartedAt,
      mixCoolStaffId: mixCoolStaffId != null ? mixCoolStaffId() : this.mixCoolStaffId,
      mixCoolStaffName: mixCoolStaffName != null ? mixCoolStaffName() : this.mixCoolStaffName,
      phCheckStaffId: phCheckStaffId != null ? phCheckStaffId() : this.phCheckStaffId,
      phCheckStaffName: phCheckStaffName != null ? phCheckStaffName() : this.phCheckStaffName,
      phReading: phReading != null ? phReading() : this.phReading,
      phReadingAt: phReadingAt != null ? phReadingAt() : this.phReadingAt,
      correctiveActionTaken: correctiveActionTaken ?? this.correctiveActionTaken,
      correctiveActionTakenAt:
          correctiveActionTakenAt != null ? correctiveActionTakenAt() : this.correctiveActionTakenAt,
      correctivePhValue: correctivePhValue != null ? correctivePhValue() : this.correctivePhValue,
      labelPrinted: labelPrinted ?? this.labelPrinted,
      readyToUseStartedAt:
          readyToUseStartedAt != null ? readyToUseStartedAt() : this.readyToUseStartedAt,
      lastAcknowledgedHour:
          lastAcknowledgedHour != null ? lastAcknowledgedHour() : this.lastAcknowledgedHour,
      currentStageAlarmId:
          currentStageAlarmId != null ? currentStageAlarmId() : this.currentStageAlarmId,
      tphcAlarmIds: tphcAlarmIds ?? this.tphcAlarmIds,
      finalBatchStatus: finalBatchStatus != null ? finalBatchStatus() : this.finalBatchStatus,
      finalStatusStaffId: finalStatusStaffId != null ? finalStatusStaffId() : this.finalStatusStaffId,
      finalStatusStaffName:
          finalStatusStaffName != null ? finalStatusStaffName() : this.finalStatusStaffName,
      foodName: foodName ?? this.foodName,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      finishedAt: finishedAt != null ? finishedAt() : this.finishedAt,
    );
  }

  factory SushiRiceBatch.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(String key) =>
        data[key] != null ? DateTime.fromMillisecondsSinceEpoch(data[key] as int) : null;

    return SushiRiceBatch(
      id: id,
      batchCode: data['batchCode'] as String,
      stage: SushiRiceStage.values.byName(data['stage'] as String),
      riceWeightLbs: (data['riceWeightLbs'] as num?)?.toDouble(),
      ricePotSanitized: data['ricePotSanitized'] as bool? ?? false,
      riceInspectedWashed: data['riceInspectedWashed'] as bool? ?? false,
      enzymeAdded: data['enzymeAdded'] as bool? ?? false,
      soakMinutes: data['soakMinutes'] as int?,
      soakStartedAt: parseDate('soakStartedAtMillis'),
      staffId: data['staffId'] as String?,
      staffName: data['staffName'] as String?,
      cookRestMinutes: data['cookRestMinutes'] as int?,
      cookRestStartedAt: parseDate('cookRestStartedAtMillis'),
      cookRestStaffId: data['cookRestStaffId'] as String?,
      cookRestStaffName: data['cookRestStaffName'] as String?,
      vinegarAmountOz: (data['vinegarAmountOz'] as num?)?.toDouble(),
      mixCoolMinutes: data['mixCoolMinutes'] as int?,
      mixCoolStartedAt: parseDate('mixCoolStartedAtMillis'),
      mixCoolStaffId: data['mixCoolStaffId'] as String?,
      mixCoolStaffName: data['mixCoolStaffName'] as String?,
      phCheckStaffId: data['phCheckStaffId'] as String?,
      phCheckStaffName: data['phCheckStaffName'] as String?,
      phReading: (data['phReading'] as num?)?.toDouble(),
      phReadingAt: parseDate('phReadingAtMillis'),
      correctiveActionTaken: data['correctiveActionTaken'] as bool? ?? false,
      correctiveActionTakenAt: parseDate('correctiveActionTakenAtMillis'),
      correctivePhValue: (data['correctivePhValue'] as num?)?.toDouble(),
      labelPrinted: data['labelPrinted'] as bool? ?? false,
      readyToUseStartedAt: parseDate('readyToUseStartedAtMillis'),
      lastAcknowledgedHour: data['lastAcknowledgedHour'] as int?,
      currentStageAlarmId: data['currentStageAlarmId'] as String?,
      tphcAlarmIds: (data['tphcAlarmIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      finalBatchStatus: data['finalBatchStatus'] as String?,
      finalStatusStaffId: data['finalStatusStaffId'] as String?,
      finalStatusStaffName: data['finalStatusStaffName'] as String?,
      foodName: data['foodName'] as String?,
      locationId: data['locationId'] as String?,
      locationName: data['locationName'] as String?,
      finishedAt: parseDate('finishedAtMillis'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batchCode': batchCode,
      'stage': stage.name,
      if (riceWeightLbs != null) 'riceWeightLbs': riceWeightLbs,
      'ricePotSanitized': ricePotSanitized,
      'riceInspectedWashed': riceInspectedWashed,
      'enzymeAdded': enzymeAdded,
      if (soakMinutes != null) 'soakMinutes': soakMinutes,
      if (soakStartedAt != null) 'soakStartedAtMillis': soakStartedAt!.millisecondsSinceEpoch,
      if (staffId != null) 'staffId': staffId,
      if (staffName != null) 'staffName': staffName,
      if (cookRestMinutes != null) 'cookRestMinutes': cookRestMinutes,
      if (cookRestStartedAt != null)
        'cookRestStartedAtMillis': cookRestStartedAt!.millisecondsSinceEpoch,
      if (cookRestStaffId != null) 'cookRestStaffId': cookRestStaffId,
      if (cookRestStaffName != null) 'cookRestStaffName': cookRestStaffName,
      if (vinegarAmountOz != null) 'vinegarAmountOz': vinegarAmountOz,
      if (mixCoolMinutes != null) 'mixCoolMinutes': mixCoolMinutes,
      if (mixCoolStartedAt != null)
        'mixCoolStartedAtMillis': mixCoolStartedAt!.millisecondsSinceEpoch,
      if (mixCoolStaffId != null) 'mixCoolStaffId': mixCoolStaffId,
      if (mixCoolStaffName != null) 'mixCoolStaffName': mixCoolStaffName,
      if (phCheckStaffId != null) 'phCheckStaffId': phCheckStaffId,
      if (phCheckStaffName != null) 'phCheckStaffName': phCheckStaffName,
      if (phReading != null) 'phReading': phReading,
      if (phReadingAt != null) 'phReadingAtMillis': phReadingAt!.millisecondsSinceEpoch,
      'correctiveActionTaken': correctiveActionTaken,
      if (correctiveActionTakenAt != null)
        'correctiveActionTakenAtMillis': correctiveActionTakenAt!.millisecondsSinceEpoch,
      if (correctivePhValue != null) 'correctivePhValue': correctivePhValue,
      'labelPrinted': labelPrinted,
      if (readyToUseStartedAt != null)
        'readyToUseStartedAtMillis': readyToUseStartedAt!.millisecondsSinceEpoch,
      if (lastAcknowledgedHour != null) 'lastAcknowledgedHour': lastAcknowledgedHour,
      if (currentStageAlarmId != null) 'currentStageAlarmId': currentStageAlarmId,
      'tphcAlarmIds': tphcAlarmIds,
      if (finalBatchStatus != null) 'finalBatchStatus': finalBatchStatus,
      if (finalStatusStaffId != null) 'finalStatusStaffId': finalStatusStaffId,
      if (finalStatusStaffName != null) 'finalStatusStaffName': finalStatusStaffName,
      if (foodName != null) 'foodName': foodName,
      if (locationId != null) 'locationId': locationId,
      if (locationName != null) 'locationName': locationName,
      if (finishedAt != null) 'finishedAtMillis': finishedAt!.millisecondsSinceEpoch,
    };
  }
}
