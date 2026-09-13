import 'log_record.dart';
import 'log_type.dart';

/// The fixed hot-holding checkpoints on the paper "Rice Hot Holding Log".
const riceHotHoldOffsets = [2, 4, 6];

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
/// temp, the +2 / +4 / +6 hour checks, and when it finished/was discarded.
class RiceHotHoldRecord implements LogRecord {
  RiceHotHoldRecord({
    required this.id,
    required this.date,
    this.foodItemName = '',
    this.batchNo = '',
    this.start,
    this.startInitials = '',
    this.actualTempF,
    this.actualTempInitials = '',
    List<RiceHotHoldCheck>? checks,
    this.finishedTime,
    this.discardTime,
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

  final String foodItemName;
  final String batchNo;

  /// Full date + time hot holding began ("Start" column).
  final DateTime? start;

  /// Who recorded the start time/temp.
  final String startInitials;

  final double? actualTempF;

  /// Who took the actual (start) temperature.
  final String actualTempInitials;

  /// Always length 3, ordered by [riceHotHoldOffsets].
  final List<RiceHotHoldCheck> checks;

  /// When hot holding for this batch ended.
  final DayTime? finishedTime;

  /// When the batch was actually discarded (may be later than
  /// [finishedTime] if it sat before being thrown out).
  final DayTime? discardTime;

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
    String? foodItemName,
    String? batchNo,
    DateTime? Function()? start,
    String? startInitials,
    double? Function()? actualTempF,
    String? actualTempInitials,
    List<RiceHotHoldCheck>? checks,
    DayTime? Function()? finishedTime,
    DayTime? Function()? discardTime,
    String? correctiveAction,
    String? initials,
  }) {
    return RiceHotHoldRecord(
      id: id,
      date: date ?? this.date,
      foodItemName: foodItemName ?? this.foodItemName,
      batchNo: batchNo ?? this.batchNo,
      start: start != null ? start() : this.start,
      startInitials: startInitials ?? this.startInitials,
      actualTempF: actualTempF != null ? actualTempF() : this.actualTempF,
      actualTempInitials: actualTempInitials ?? this.actualTempInitials,
      checks: checks ?? this.checks,
      finishedTime: finishedTime != null ? finishedTime() : this.finishedTime,
      discardTime: discardTime != null ? discardTime() : this.discardTime,
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
      foodItemName: data['foodItemName'] as String? ?? '',
      batchNo: data['batchNo'] as String? ?? '',
      start: logRecordDateTimeFromMap(data, 'startMillis'),
      startInitials: data['startInitials'] as String? ?? '',
      actualTempF: (data['actualTempF'] as num?)?.toDouble(),
      actualTempInitials: data['actualTempInitials'] as String? ?? '',
      checks: checks,
      finishedTime: DayTime.fromMinutesOrNull(data['finishedTimeMin'] as int?),
      discardTime: DayTime.fromMinutesOrNull(data['discardTimeMin'] as int?),
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
      if (start != null) 'startMillis': start!.millisecondsSinceEpoch,
      'startInitials': startInitials,
      if (actualTempF != null) 'actualTempF': actualTempF,
      'actualTempInitials': actualTempInitials,
      'checks': [for (final c in checks) c.toMap()],
      if (finishedTime != null) 'finishedTimeMin': finishedTime!.minutesSinceMidnight,
      if (discardTime != null) 'discardTimeMin': discardTime!.minutesSinceMidnight,
      'correctiveAction': correctiveAction,
      'initials': initials,
    };
  }
}
