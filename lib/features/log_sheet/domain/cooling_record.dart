import 'log_record.dart';
import 'log_type.dart';

/// One row of the "Cooling Log" — two-stage cooling of a cooked food:
/// Stage 1 is 135°F → 70°F within 2 hours, Stage 2 is → 41°F or below
/// within 6 hours total.
class CoolingRecord implements LogRecord {
  const CoolingRecord({
    required this.id,
    required this.date,
    this.foodItemName = '',
    this.batchNo = '',
    this.coolingStart,
    this.initialTempF,
    this.stage1Time,
    this.stage1TempF,
    this.stage1Initials = '',
    this.stage2Time,
    this.stage2TempF,
    this.stage2Initials = '',
    this.correctiveAction = '',
    this.initials = '',
    this.createdAt,
    this.updatedAt,
  });

  @override
  final String id;

  /// The cooling day — kept in sync with [coolingStart] when that is set.
  @override
  final DateTime date;

  final String foodItemName;
  final String batchNo;

  /// Full date + time cooling began ("Cooling Start" column).
  final DateTime? coolingStart;
  final double? initialTempF;
  final DayTime? stage1Time;
  final double? stage1TempF;

  /// Who took the Stage 1 (135°F → 70°F) reading.
  final String stage1Initials;

  final DayTime? stage2Time;
  final double? stage2TempF;

  /// Who took the Stage 2 (→ 41°F) reading.
  final String stage2Initials;

  final String correctiveAction;

  @override
  final String initials;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  LogType get logType => LogType.cooling;

  @override
  int get timeSortKey =>
      coolingStart == null ? 0 : coolingStart!.hour * 60 + coolingStart!.minute;

  String get dateLabel => logRecordDateLabel(date);
  static String tempLabel(double? f) => f == null ? '-' : '${f.toStringAsFixed(0)}°F';
  String get correctiveActionLabel => correctiveAction.trim().isEmpty ? 'None' : correctiveAction;

  CoolingRecord copyWith({
    DateTime? date,
    String? foodItemName,
    String? batchNo,
    DateTime? Function()? coolingStart,
    double? Function()? initialTempF,
    DayTime? Function()? stage1Time,
    double? Function()? stage1TempF,
    String? stage1Initials,
    DayTime? Function()? stage2Time,
    double? Function()? stage2TempF,
    String? stage2Initials,
    String? correctiveAction,
    String? initials,
  }) {
    return CoolingRecord(
      id: id,
      date: date ?? this.date,
      foodItemName: foodItemName ?? this.foodItemName,
      batchNo: batchNo ?? this.batchNo,
      coolingStart: coolingStart != null ? coolingStart() : this.coolingStart,
      initialTempF: initialTempF != null ? initialTempF() : this.initialTempF,
      stage1Time: stage1Time != null ? stage1Time() : this.stage1Time,
      stage1TempF: stage1TempF != null ? stage1TempF() : this.stage1TempF,
      stage1Initials: stage1Initials ?? this.stage1Initials,
      stage2Time: stage2Time != null ? stage2Time() : this.stage2Time,
      stage2TempF: stage2TempF != null ? stage2TempF() : this.stage2TempF,
      stage2Initials: stage2Initials ?? this.stage2Initials,
      correctiveAction: correctiveAction ?? this.correctiveAction,
      initials: initials ?? this.initials,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory CoolingRecord.fromMap(String id, Map<String, dynamic> data) {
    return CoolingRecord(
      id: id,
      date: logRecordDateFromMap(data),
      foodItemName: data['foodItemName'] as String? ?? '',
      batchNo: data['batchNo'] as String? ?? '',
      coolingStart: logRecordDateTimeFromMap(data, 'coolingStartMillis'),
      initialTempF: (data['initialTempF'] as num?)?.toDouble(),
      stage1Time: DayTime.fromMinutesOrNull(data['stage1TimeMin'] as int?),
      stage1TempF: (data['stage1TempF'] as num?)?.toDouble(),
      stage1Initials: data['stage1Initials'] as String? ?? '',
      stage2Time: DayTime.fromMinutesOrNull(data['stage2TimeMin'] as int?),
      stage2TempF: (data['stage2TempF'] as num?)?.toDouble(),
      stage2Initials: data['stage2Initials'] as String? ?? '',
      correctiveAction: data['correctiveAction'] as String? ?? '',
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
      'foodItemName': foodItemName,
      'batchNo': batchNo,
      if (coolingStart != null) 'coolingStartMillis': coolingStart!.millisecondsSinceEpoch,
      if (initialTempF != null) 'initialTempF': initialTempF,
      if (stage1Time != null) 'stage1TimeMin': stage1Time!.minutesSinceMidnight,
      if (stage1TempF != null) 'stage1TempF': stage1TempF,
      'stage1Initials': stage1Initials,
      if (stage2Time != null) 'stage2TimeMin': stage2Time!.minutesSinceMidnight,
      if (stage2TempF != null) 'stage2TempF': stage2TempF,
      'stage2Initials': stage2Initials,
      'correctiveAction': correctiveAction,
      'initials': initials,
    };
  }
}
