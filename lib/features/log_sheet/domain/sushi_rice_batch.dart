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
/// of the window. Soak: 20–30 min. Cook & Rest: 45–50 min (the actual
/// cooking time — see [sushiRiceMixByMaxMinutes] for the separate
/// post-cook mixing deadline). Mixing & Cooling: 1–30 min.
const sushiRiceSoakUnlockMinutes = 20;
const sushiRiceSoakTotalMinutes = 30;

/// Soaking method, chosen on the Soaking setup screen — each carries its
/// own food-safety deadline for how long the batch may sit before cooking
/// must start, shown as a "Critical: Must cook in X hours" hint next to
/// the picker.
const sushiRiceSoakingMethods = ['Refrigerator', 'Room Temperature'];
const sushiRiceSoakingMethodMaxHours = {'Refrigerator': 72, 'Room Temperature': 2};
const sushiRiceCookRestUnlockMinutes = 45;
const sushiRiceCookRestTotalMinutes = 50;

/// How long, after Cook & Rest's own 45–50 min cook timer ends
/// ([SushiRiceBatch.cookRestEndsAt]), staff still has to actually start
/// mixing — 1 to 30 minutes. Past that, the batch can no longer be mixed
/// at all and must be discarded instead (see
/// [SushiRiceBatch.cookRestMixByDeadline] / the "Mixing Window Expired"
/// card) — a separate, later deadline from the cook timer itself, unlike
/// Soak/Mixing & Cooling's plain "Time's Up!" state, which still allows
/// the action late with no hard cutoff.
const sushiRiceMixByUnlockMinutes = 1;
const sushiRiceMixByMaxMinutes = 30;

const sushiRiceMixCoolUnlockMinutes = 1;
const sushiRiceMixCoolTotalMinutes = 30;

/// How long staff has to actually measure and save the pH reading once
/// pH Check starts (see [SushiRiceBatch.phCheckStartedAt]/[phCheckEndsAt])
/// — same 30-min window as every other stage, shown as a plain "Time's
/// Up!" state past it (no separate hard discard deadline, matching
/// Mixing & Cooling's treatment rather than Cooking & Rest's).
const sushiRicePhCheckMaxMinutes = 30;

/// Preset vinegar amounts (in cups) offered when advancing Cooking & Rest
/// -> Mixing & Cooling — staff can also type a custom amount instead of
/// picking one of these.
const sushiRiceVinegarAmountsCups = [4.0, 2.0];

/// Vinegar amounts (in cups) offered on a pH corrective retest — a
/// separate, finer-grained list from [sushiRiceVinegarAmountsCups] since
/// correcting a failed batch is a smaller top-up, not the original mix.
const sushiRiceCorrectiveVinegarAmountsCups = [1.0, 2.0, 3.0, 4.0];

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

/// Preset reasons offered when discarding a batch whose Soaking critical
/// window (see [sushiRiceSoakingMethodMaxHours]) has expired.
const sushiRiceDiscardReasons = [
  'Cooking window expired',
  'Food safety concern',
  'Incorrect preparation',
  'Contamination',
];

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
    this.soakingMethod,
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
    this.phCheckStartedAt,
    this.phCheckStaffId,
    this.phCheckStaffName,
    this.phReading,
    this.phReadingAt,
    this.correctiveActionTaken = false,
    this.correctiveActionTakenAt,
    this.correctivePhValue,
    this.correctiveVinegarAmountOz,
    this.labelPrinted = false,
    this.readyToUseStartedAt,
    this.lastAcknowledgedHour,
    this.currentStageAlarmId,
    this.tphcAlarmIds = const [],
    this.finalBatchStatus,
    this.finalStatusStaffId,
    this.finalStatusStaffName,
    this.discardReason,
    this.discardRemark,
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

  /// "Refrigerator" or "Room Temperature" — chosen on the Soaking setup
  /// screen; see [sushiRiceSoakingMethods]/[sushiRiceSoakingMethodMaxHours].
  final String? soakingMethod;

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
  /// the staff who takes the pH reading(s) below. [phCheckStartedAt]
  /// anchors [phCheckEndsAt] (the 30-min window to measure and save).
  final DateTime? phCheckStartedAt;
  final String? phCheckStaffId;
  final String? phCheckStaffName;

  /// The latest pH reading (a retest after [correctiveActionTaken]
  /// overwrites this with the new value) and when it was taken.
  final double? phReading;
  final DateTime? phReadingAt;

  /// Set once a reading has failed (> [sushiRicePhPassThreshold]) and the
  /// batch is retested — [correctivePhValue] is the passing retest value,
  /// [correctiveVinegarAmountOz] the extra vinegar added before retesting.
  final bool correctiveActionTaken;
  final DateTime? correctiveActionTakenAt;
  final double? correctivePhValue;
  final double? correctiveVinegarAmountOz;

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

  /// Set when [finalBatchStatus] is 'Discarded' via the "Cooking Window
  /// Expired" card — one of [sushiRiceDiscardReasons] plus an optional
  /// free-text note.
  final String? discardReason;
  final String? discardRemark;

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

  /// The 30-min window ([sushiRicePhCheckMaxMinutes]) staff has, once pH
  /// Check starts, to measure and save the reading.
  DateTime? get phCheckEndsAt =>
      phCheckStartedAt?.add(const Duration(minutes: sushiRicePhCheckMaxMinutes));

  /// The hard deadline by which mixing must start once Cook & Rest's own
  /// 45–50 min cook timer ends — [sushiRiceMixByMaxMinutes] after
  /// [cookRestEndsAt], not after [cookRestStartedAt]. Past this, mixing is
  /// no longer safe and the batch must be discarded.
  DateTime? get cookRestMixByDeadline =>
      cookRestEndsAt?.add(const Duration(minutes: sushiRiceMixByMaxMinutes));

  /// The 24-hr TPHC shelf-life deadline — counted from [mixCoolStartedAt]
  /// (the moment vinegar was added, which doubles as "Vinegar Mixing Time"
  /// on the log sheet), not from [readyToUseStartedAt] (when pH happened
  /// to pass, which can be up to ~30 min later). Explicit product decision:
  /// the rice's shelf clock starts at the vinegar add, regardless of how
  /// long the pH check itself took.
  DateTime? get readyToUseDeadline =>
      mixCoolStartedAt?.add(const Duration(hours: sushiRiceReadyToUseWindowHours));

  /// The food-safety deadline by which cooking must start, per
  /// [soakingMethod] (see [sushiRiceSoakingMethodMaxHours]) — separate from
  /// [soakEndsAt], which is only the fixed 20–30 min "Start Cooking" buzzer.
  /// Past this, the rice has sat too long to safely cook and the batch must
  /// be discarded instead.
  DateTime? get soakCookByDeadline {
    final startedAt = soakStartedAt;
    final maxHours = sushiRiceSoakingMethodMaxHours[soakingMethod];
    if (startedAt == null || maxHours == null) return null;
    return startedAt.add(Duration(hours: maxHours));
  }

  SushiRiceBatch copyWith({
    SushiRiceStage? stage,
    double? Function()? riceWeightLbs,
    bool? ricePotSanitized,
    bool? riceInspectedWashed,
    bool? enzymeAdded,
    String? Function()? soakingMethod,
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
    DateTime? Function()? phCheckStartedAt,
    String? Function()? phCheckStaffId,
    String? Function()? phCheckStaffName,
    double? Function()? phReading,
    DateTime? Function()? phReadingAt,
    bool? correctiveActionTaken,
    DateTime? Function()? correctiveActionTakenAt,
    double? Function()? correctivePhValue,
    double? Function()? correctiveVinegarAmountOz,
    bool? labelPrinted,
    DateTime? Function()? readyToUseStartedAt,
    int? Function()? lastAcknowledgedHour,
    String? Function()? currentStageAlarmId,
    List<String>? tphcAlarmIds,
    String? Function()? finalBatchStatus,
    String? Function()? finalStatusStaffId,
    String? Function()? finalStatusStaffName,
    String? Function()? discardReason,
    String? Function()? discardRemark,
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
      soakingMethod: soakingMethod != null ? soakingMethod() : this.soakingMethod,
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
      phCheckStartedAt: phCheckStartedAt != null ? phCheckStartedAt() : this.phCheckStartedAt,
      phCheckStaffId: phCheckStaffId != null ? phCheckStaffId() : this.phCheckStaffId,
      phCheckStaffName: phCheckStaffName != null ? phCheckStaffName() : this.phCheckStaffName,
      phReading: phReading != null ? phReading() : this.phReading,
      phReadingAt: phReadingAt != null ? phReadingAt() : this.phReadingAt,
      correctiveActionTaken: correctiveActionTaken ?? this.correctiveActionTaken,
      correctiveActionTakenAt:
          correctiveActionTakenAt != null ? correctiveActionTakenAt() : this.correctiveActionTakenAt,
      correctivePhValue: correctivePhValue != null ? correctivePhValue() : this.correctivePhValue,
      correctiveVinegarAmountOz: correctiveVinegarAmountOz != null
          ? correctiveVinegarAmountOz()
          : this.correctiveVinegarAmountOz,
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
      discardReason: discardReason != null ? discardReason() : this.discardReason,
      discardRemark: discardRemark != null ? discardRemark() : this.discardRemark,
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
      soakingMethod: data['soakingMethod'] as String?,
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
      phCheckStartedAt: parseDate('phCheckStartedAtMillis'),
      phCheckStaffId: data['phCheckStaffId'] as String?,
      phCheckStaffName: data['phCheckStaffName'] as String?,
      phReading: (data['phReading'] as num?)?.toDouble(),
      phReadingAt: parseDate('phReadingAtMillis'),
      correctiveActionTaken: data['correctiveActionTaken'] as bool? ?? false,
      correctiveActionTakenAt: parseDate('correctiveActionTakenAtMillis'),
      correctivePhValue: (data['correctivePhValue'] as num?)?.toDouble(),
      correctiveVinegarAmountOz: (data['correctiveVinegarAmountOz'] as num?)?.toDouble(),
      labelPrinted: data['labelPrinted'] as bool? ?? false,
      readyToUseStartedAt: parseDate('readyToUseStartedAtMillis'),
      lastAcknowledgedHour: data['lastAcknowledgedHour'] as int?,
      currentStageAlarmId: data['currentStageAlarmId'] as String?,
      tphcAlarmIds: (data['tphcAlarmIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      finalBatchStatus: data['finalBatchStatus'] as String?,
      finalStatusStaffId: data['finalStatusStaffId'] as String?,
      finalStatusStaffName: data['finalStatusStaffName'] as String?,
      discardReason: data['discardReason'] as String?,
      discardRemark: data['discardRemark'] as String?,
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
      if (soakingMethod != null) 'soakingMethod': soakingMethod,
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
      if (phCheckStartedAt != null)
        'phCheckStartedAtMillis': phCheckStartedAt!.millisecondsSinceEpoch,
      if (phCheckStaffId != null) 'phCheckStaffId': phCheckStaffId,
      if (phCheckStaffName != null) 'phCheckStaffName': phCheckStaffName,
      if (phReading != null) 'phReading': phReading,
      if (phReadingAt != null) 'phReadingAtMillis': phReadingAt!.millisecondsSinceEpoch,
      'correctiveActionTaken': correctiveActionTaken,
      if (correctiveActionTakenAt != null)
        'correctiveActionTakenAtMillis': correctiveActionTakenAt!.millisecondsSinceEpoch,
      if (correctivePhValue != null) 'correctivePhValue': correctivePhValue,
      if (correctiveVinegarAmountOz != null)
        'correctiveVinegarAmountOz': correctiveVinegarAmountOz,
      'labelPrinted': labelPrinted,
      if (readyToUseStartedAt != null)
        'readyToUseStartedAtMillis': readyToUseStartedAt!.millisecondsSinceEpoch,
      if (lastAcknowledgedHour != null) 'lastAcknowledgedHour': lastAcknowledgedHour,
      if (currentStageAlarmId != null) 'currentStageAlarmId': currentStageAlarmId,
      'tphcAlarmIds': tphcAlarmIds,
      if (finalBatchStatus != null) 'finalBatchStatus': finalBatchStatus,
      if (finalStatusStaffId != null) 'finalStatusStaffId': finalStatusStaffId,
      if (finalStatusStaffName != null) 'finalStatusStaffName': finalStatusStaffName,
      if (discardReason != null) 'discardReason': discardReason,
      if (discardRemark != null) 'discardRemark': discardRemark,
      if (foodName != null) 'foodName': foodName,
      if (locationId != null) 'locationId': locationId,
      if (locationName != null) 'locationName': locationName,
      if (finishedAt != null) 'finishedAtMillis': finishedAt!.millisecondsSinceEpoch,
    };
  }
}
