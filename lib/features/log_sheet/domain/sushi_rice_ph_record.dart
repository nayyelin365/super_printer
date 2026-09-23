import 'log_record.dart';
import 'log_type.dart';

/// Rice pH must not exceed this to be "in range" (targeted 4.1, never to
/// exceed 4.2) — see [SushiRicePhRecord.inRange].
const sushiRicePhMaxInRange = 4.2;

/// One day/batch column of the paper "Sushi Rice pH Log" — the pH meter
/// check, cook/acidify times, the pH reading against the 4.1 target
/// (never to exceed 4.2), any corrective vinegar addition, and the
/// discard/all-used times.
///
/// The three Yes/No fields ([phMeterCalibrated], [inRangeAfterCorrection],
/// [discardOutOfRangeRice]) are nullable rather than defaulting to false —
/// an entry the user hasn't answered yet stores/shows as unanswered ("-"),
/// not a silent "No". [inRange] is not a manual answer at all: it's
/// derived from [ricePh] against [sushiRicePhMaxInRange] (see [inRange]).
class SushiRicePhRecord implements LogRecord {
  const SushiRicePhRecord({
    required this.id,
    required this.date,
    this.phMeterCalibrated,
    this.riceBatchNo = '',
    this.timeStartCooking,
    this.timeCooked,
    this.timeAcidified,
    this.timePhMeasurement,
    this.ricePh,
    this.phAfterCorrected,
    this.amountAddingVinegar = '',
    this.inRangeAfterCorrection,
    this.discardOutOfRangeRice,
    this.timeRiceAllUsed,
    this.discardTimeAfterExpiry,
    this.initials = '',
    this.createdAt,
    this.updatedAt,
  });

  @override
  final String id;
  @override
  final DateTime date;

  final bool? phMeterCalibrated;
  final String riceBatchNo;
  final DayTime? timeStartCooking;
  final DayTime? timeCooked;
  final DayTime? timeAcidified;

  /// When the pH was actually measured (after acidifying).
  final DayTime? timePhMeasurement;
  final double? ricePh;

  final double? phAfterCorrected;
  final String amountAddingVinegar;
  final bool? inRangeAfterCorrection;
  final bool? discardOutOfRangeRice;

  /// Full date + time the rice was all used up — unlike the other time
  /// fields here, this can land on a later calendar day than [date], so it
  /// carries its own date rather than just a time-of-day.
  final DateTime? timeRiceAllUsed;

  final DayTime? discardTimeAfterExpiry;

  @override
  final String initials;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  LogType get logType => LogType.sushiRicePh;

  @override
  int get timeSortKey => timeStartCooking?.minutesSinceMidnight ?? 0;

  String get dateLabel => logRecordDateLabel(date);
  String get ricePhLabel => ricePh?.toStringAsFixed(1) ?? '-';
  String get phAfterCorrectedLabel => phAfterCorrected?.toStringAsFixed(1) ?? '-';

  /// "Targeted pH of 4.1, not to exceed 4.2 — results are in this range?"
  /// Derived from [ricePh] rather than a separate manual answer — null
  /// (shown as "-") until a pH is entered, then `ricePh <=
  /// [sushiRicePhMaxInRange]`. Only when this is false (pH over 4.2) do the
  /// correction fields ([phAfterCorrected], [amountAddingVinegar],
  /// [inRangeAfterCorrection], [discardOutOfRangeRice]) apply — see the
  /// form screen.
  bool? get inRange => ricePh == null ? null : ricePh! <= sushiRicePhMaxInRange;

  SushiRicePhRecord copyWith({
    DateTime? date,
    bool? Function()? phMeterCalibrated,
    String? riceBatchNo,
    DayTime? Function()? timeStartCooking,
    DayTime? Function()? timeCooked,
    DayTime? Function()? timeAcidified,
    DayTime? Function()? timePhMeasurement,
    double? Function()? ricePh,
    double? Function()? phAfterCorrected,
    String? amountAddingVinegar,
    bool? Function()? inRangeAfterCorrection,
    bool? Function()? discardOutOfRangeRice,
    DateTime? Function()? timeRiceAllUsed,
    DayTime? Function()? discardTimeAfterExpiry,
    String? initials,
  }) {
    return SushiRicePhRecord(
      id: id,
      date: date ?? this.date,
      phMeterCalibrated:
          phMeterCalibrated != null ? phMeterCalibrated() : this.phMeterCalibrated,
      riceBatchNo: riceBatchNo ?? this.riceBatchNo,
      timeStartCooking: timeStartCooking != null ? timeStartCooking() : this.timeStartCooking,
      timeCooked: timeCooked != null ? timeCooked() : this.timeCooked,
      timeAcidified: timeAcidified != null ? timeAcidified() : this.timeAcidified,
      timePhMeasurement:
          timePhMeasurement != null ? timePhMeasurement() : this.timePhMeasurement,
      ricePh: ricePh != null ? ricePh() : this.ricePh,
      phAfterCorrected: phAfterCorrected != null ? phAfterCorrected() : this.phAfterCorrected,
      amountAddingVinegar: amountAddingVinegar ?? this.amountAddingVinegar,
      inRangeAfterCorrection:
          inRangeAfterCorrection != null ? inRangeAfterCorrection() : this.inRangeAfterCorrection,
      discardOutOfRangeRice:
          discardOutOfRangeRice != null ? discardOutOfRangeRice() : this.discardOutOfRangeRice,
      timeRiceAllUsed: timeRiceAllUsed != null ? timeRiceAllUsed() : this.timeRiceAllUsed,
      discardTimeAfterExpiry:
          discardTimeAfterExpiry != null ? discardTimeAfterExpiry() : this.discardTimeAfterExpiry,
      initials: initials ?? this.initials,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory SushiRicePhRecord.fromMap(String id, Map<String, dynamic> data) {
    return SushiRicePhRecord(
      id: id,
      date: logRecordDateFromMap(data),
      phMeterCalibrated: data['phMeterCalibrated'] as bool?,
      riceBatchNo: data['riceBatchNo'] as String? ?? '',
      timeStartCooking: DayTime.fromMinutesOrNull(data['timeStartCookingMin'] as int?),
      timeCooked: DayTime.fromMinutesOrNull(data['timeCookedMin'] as int?),
      timeAcidified: DayTime.fromMinutesOrNull(data['timeAcidifiedMin'] as int?),
      timePhMeasurement: DayTime.fromMinutesOrNull(data['timePhMeasurementMin'] as int?),
      ricePh: (data['ricePh'] as num?)?.toDouble(),
      phAfterCorrected: (data['phAfterCorrected'] as num?)?.toDouble(),
      amountAddingVinegar: data['amountAddingVinegar'] as String? ?? '',
      inRangeAfterCorrection: data['inRangeAfterCorrection'] as bool?,
      discardOutOfRangeRice: data['discardOutOfRangeRice'] as bool?,
      timeRiceAllUsed: logRecordDateTimeFromMap(data, 'timeRiceAllUsedMillis'),
      discardTimeAfterExpiry:
          DayTime.fromMinutesOrNull(data['discardTimeAfterExpiryMin'] as int?),
      initials: data['initials'] as String? ?? '',
      createdAt: logRecordTimestampFromMap(data, 'createdAtMillis'),
      updatedAt: logRecordTimestampFromMap(data, 'updatedAtMillis'),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'logType': logType.id,
      'dateMillis': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
      if (phMeterCalibrated != null) 'phMeterCalibrated': phMeterCalibrated,
      'riceBatchNo': riceBatchNo,
      if (timeStartCooking != null) 'timeStartCookingMin': timeStartCooking!.minutesSinceMidnight,
      if (timeCooked != null) 'timeCookedMin': timeCooked!.minutesSinceMidnight,
      if (timeAcidified != null) 'timeAcidifiedMin': timeAcidified!.minutesSinceMidnight,
      if (timePhMeasurement != null)
        'timePhMeasurementMin': timePhMeasurement!.minutesSinceMidnight,
      if (ricePh != null) 'ricePh': ricePh,
      // `inRange` itself isn't stored — it's derived from `ricePh` on read.
      if (phAfterCorrected != null) 'phAfterCorrected': phAfterCorrected,
      'amountAddingVinegar': amountAddingVinegar,
      if (inRangeAfterCorrection != null) 'inRangeAfterCorrection': inRangeAfterCorrection,
      if (discardOutOfRangeRice != null) 'discardOutOfRangeRice': discardOutOfRangeRice,
      if (timeRiceAllUsed != null) 'timeRiceAllUsedMillis': timeRiceAllUsed!.millisecondsSinceEpoch,
      if (discardTimeAfterExpiry != null)
        'discardTimeAfterExpiryMin': discardTimeAfterExpiry!.minutesSinceMidnight,
      'initials': initials,
    };
  }
}
