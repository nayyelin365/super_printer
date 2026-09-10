import 'log_record.dart';
import 'log_type.dart';

/// One day/batch column of the paper "Sushi Rice pH Log" — the pH meter
/// check, cook/acidify times, the pH reading against the 4.1 target
/// (never to exceed 4.2), any corrective vinegar addition, and the
/// discard/all-used times.
class SushiRicePhRecord implements LogRecord {
  const SushiRicePhRecord({
    required this.id,
    required this.date,
    required this.locationId,
    required this.locationName,
    this.phMeterCalibrated = false,
    this.riceBatchNo = '',
    this.timeStartCooking,
    this.timeCooked,
    this.timeAcidified,
    this.ricePh,
    this.inRange = false,
    this.phAfterCorrected,
    this.amountAddingVinegar = '',
    this.inRangeAfterCorrection = false,
    this.discardOutOfRangeRice = false,
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
  @override
  final String locationId;
  @override
  final String locationName;

  final bool phMeterCalibrated;
  final String riceBatchNo;
  final DayTime? timeStartCooking;
  final DayTime? timeCooked;
  final DayTime? timeAcidified;
  final double? ricePh;

  /// "Targeted pH of 4.1, not to exceed 4.2 — results are in this range?"
  final bool inRange;

  final double? phAfterCorrected;
  final String amountAddingVinegar;
  final bool inRangeAfterCorrection;
  final bool discardOutOfRangeRice;
  final DayTime? timeRiceAllUsed;
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

  SushiRicePhRecord copyWith({
    DateTime? date,
    String? locationId,
    String? locationName,
    bool? phMeterCalibrated,
    String? riceBatchNo,
    DayTime? Function()? timeStartCooking,
    DayTime? Function()? timeCooked,
    DayTime? Function()? timeAcidified,
    double? Function()? ricePh,
    bool? inRange,
    double? Function()? phAfterCorrected,
    String? amountAddingVinegar,
    bool? inRangeAfterCorrection,
    bool? discardOutOfRangeRice,
    DayTime? Function()? timeRiceAllUsed,
    DayTime? Function()? discardTimeAfterExpiry,
    String? initials,
  }) {
    return SushiRicePhRecord(
      id: id,
      date: date ?? this.date,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      phMeterCalibrated: phMeterCalibrated ?? this.phMeterCalibrated,
      riceBatchNo: riceBatchNo ?? this.riceBatchNo,
      timeStartCooking: timeStartCooking != null ? timeStartCooking() : this.timeStartCooking,
      timeCooked: timeCooked != null ? timeCooked() : this.timeCooked,
      timeAcidified: timeAcidified != null ? timeAcidified() : this.timeAcidified,
      ricePh: ricePh != null ? ricePh() : this.ricePh,
      inRange: inRange ?? this.inRange,
      phAfterCorrected: phAfterCorrected != null ? phAfterCorrected() : this.phAfterCorrected,
      amountAddingVinegar: amountAddingVinegar ?? this.amountAddingVinegar,
      inRangeAfterCorrection: inRangeAfterCorrection ?? this.inRangeAfterCorrection,
      discardOutOfRangeRice: discardOutOfRangeRice ?? this.discardOutOfRangeRice,
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
      locationId: data['locationId'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      phMeterCalibrated: data['phMeterCalibrated'] as bool? ?? false,
      riceBatchNo: data['riceBatchNo'] as String? ?? '',
      timeStartCooking: DayTime.fromMinutesOrNull(data['timeStartCookingMin'] as int?),
      timeCooked: DayTime.fromMinutesOrNull(data['timeCookedMin'] as int?),
      timeAcidified: DayTime.fromMinutesOrNull(data['timeAcidifiedMin'] as int?),
      ricePh: (data['ricePh'] as num?)?.toDouble(),
      inRange: data['inRange'] as bool? ?? false,
      phAfterCorrected: (data['phAfterCorrected'] as num?)?.toDouble(),
      amountAddingVinegar: data['amountAddingVinegar'] as String? ?? '',
      inRangeAfterCorrection: data['inRangeAfterCorrection'] as bool? ?? false,
      discardOutOfRangeRice: data['discardOutOfRangeRice'] as bool? ?? false,
      timeRiceAllUsed: DayTime.fromMinutesOrNull(data['timeRiceAllUsedMin'] as int?),
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
      'locationId': locationId,
      'locationName': locationName,
      'phMeterCalibrated': phMeterCalibrated,
      'riceBatchNo': riceBatchNo,
      if (timeStartCooking != null) 'timeStartCookingMin': timeStartCooking!.minutesSinceMidnight,
      if (timeCooked != null) 'timeCookedMin': timeCooked!.minutesSinceMidnight,
      if (timeAcidified != null) 'timeAcidifiedMin': timeAcidified!.minutesSinceMidnight,
      if (ricePh != null) 'ricePh': ricePh,
      'inRange': inRange,
      if (phAfterCorrected != null) 'phAfterCorrected': phAfterCorrected,
      'amountAddingVinegar': amountAddingVinegar,
      'inRangeAfterCorrection': inRangeAfterCorrection,
      'discardOutOfRangeRice': discardOutOfRangeRice,
      if (timeRiceAllUsed != null) 'timeRiceAllUsedMin': timeRiceAllUsed!.minutesSinceMidnight,
      if (discardTimeAfterExpiry != null)
        'discardTimeAfterExpiryMin': discardTimeAfterExpiry!.minutesSinceMidnight,
      'initials': initials,
    };
  }
}
