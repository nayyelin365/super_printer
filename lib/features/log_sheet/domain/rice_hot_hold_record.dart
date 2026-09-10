import 'log_record.dart';
import 'log_type.dart';

/// The fixed hot-holding checkpoints on the paper "Rice Hot Holding Log".
const riceHotHoldOffsets = [2, 4, 6, 8];

/// One hot-holding temperature check taken at [hourOffset] hours after the
/// hold started.
class RiceHotHoldCheck {
  const RiceHotHoldCheck({
    required this.hourOffset,
    this.time,
    this.tempF,
    this.initials = '',
  });

  final int hourOffset;
  final DayTime? time;
  final double? tempF;
  final String initials;

  RiceHotHoldCheck copyWith({
    DayTime? Function()? time,
    double? Function()? tempF,
    String? initials,
  }) {
    return RiceHotHoldCheck(
      hourOffset: hourOffset,
      time: time != null ? time() : this.time,
      tempF: tempF != null ? tempF() : this.tempF,
      initials: initials ?? this.initials,
    );
  }

  factory RiceHotHoldCheck.fromMap(Map<String, dynamic> data) {
    return RiceHotHoldCheck(
      hourOffset: data['hourOffset'] as int,
      time: DayTime.fromMinutesOrNull(data['timeMin'] as int?),
      tempF: (data['tempF'] as num?)?.toDouble(),
      initials: data['initials'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'hourOffset': hourOffset,
        if (time != null) 'timeMin': time!.minutesSinceMidnight,
        if (tempF != null) 'tempF': tempF,
        'initials': initials,
      };
}

/// One row of the "Rice Hot Holding Log" — a batch held hot, its start
/// temp, and the +2 / +4 / +6 / +8 hour checks.
class RiceHotHoldRecord implements LogRecord {
  RiceHotHoldRecord({
    required this.id,
    required this.date,
    required this.locationId,
    required this.locationName,
    this.foodItemName = '',
    this.batchNo = '',
    this.start,
    this.actualTempF,
    List<RiceHotHoldCheck>? checks,
    this.correctiveAction = '',
    this.initials = '',
    this.createdAt,
    this.updatedAt,
  }) : checks = checks ?? defaultChecks();

  static List<RiceHotHoldCheck> defaultChecks() =>
      [for (final h in riceHotHoldOffsets) RiceHotHoldCheck(hourOffset: h)];

  @override
  final String id;
  @override
  final DateTime date;
  @override
  final String locationId;
  @override
  final String locationName;

  final String foodItemName;
  final String batchNo;

  /// Full date + time hot holding began ("Start" column).
  final DateTime? start;
  final double? actualTempF;

  /// Always length 4, ordered by [riceHotHoldOffsets].
  final List<RiceHotHoldCheck> checks;
  final String correctiveAction;

  @override
  final String initials;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  LogType get logType => LogType.riceHotHold;

  @override
  int get timeSortKey => start == null ? 0 : start!.hour * 60 + start!.minute;

  String get dateLabel => logRecordDateLabel(date);
  static String tempLabel(double? f) => f == null ? '-' : '${f.toStringAsFixed(0)}°F';
  String get correctiveActionLabel => correctiveAction.trim().isEmpty ? 'None' : correctiveAction;

  RiceHotHoldCheck checkAt(int hourOffset) =>
      checks.firstWhere((c) => c.hourOffset == hourOffset);

  RiceHotHoldRecord copyWith({
    DateTime? date,
    String? locationId,
    String? locationName,
    String? foodItemName,
    String? batchNo,
    DateTime? Function()? start,
    double? Function()? actualTempF,
    List<RiceHotHoldCheck>? checks,
    String? correctiveAction,
    String? initials,
  }) {
    return RiceHotHoldRecord(
      id: id,
      date: date ?? this.date,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      foodItemName: foodItemName ?? this.foodItemName,
      batchNo: batchNo ?? this.batchNo,
      start: start != null ? start() : this.start,
      actualTempF: actualTempF != null ? actualTempF() : this.actualTempF,
      checks: checks ?? this.checks,
      correctiveAction: correctiveAction ?? this.correctiveAction,
      initials: initials ?? this.initials,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory RiceHotHoldRecord.fromMap(String id, Map<String, dynamic> data) {
    final rawChecks = (data['checks'] as List<dynamic>? ?? const [])
        .map((c) => RiceHotHoldCheck.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList();
    // Guarantee one entry per fixed offset even if a stored doc is partial.
    final checks = [
      for (final h in riceHotHoldOffsets)
        rawChecks.firstWhere(
          (c) => c.hourOffset == h,
          orElse: () => RiceHotHoldCheck(hourOffset: h),
        ),
    ];
    return RiceHotHoldRecord(
      id: id,
      date: logRecordDateFromMap(data),
      locationId: data['locationId'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      foodItemName: data['foodItemName'] as String? ?? '',
      batchNo: data['batchNo'] as String? ?? '',
      start: logRecordDateTimeFromMap(data, 'startMillis'),
      actualTempF: (data['actualTempF'] as num?)?.toDouble(),
      checks: checks,
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
      'locationId': locationId,
      'locationName': locationName,
      'foodItemName': foodItemName,
      'batchNo': batchNo,
      if (start != null) 'startMillis': start!.millisecondsSinceEpoch,
      if (actualTempF != null) 'actualTempF': actualTempF,
      'checks': [for (final c in checks) c.toMap()],
      'correctiveAction': correctiveAction,
      'initials': initials,
    };
  }
}
