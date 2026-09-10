import 'log_type.dart';

/// A time of day (no date) stored as minutes since midnight — the shape the
/// four log records use for their many optional "time" fields (e.g. "Time
/// Acidified", "Stage 1 Time"). Kept small and immutable; formatting lives
/// here so every screen/export renders times identically.
class DayTime {
  const DayTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  static DayTime fromMinutes(int minutes) => DayTime(minutes ~/ 60, minutes % 60);

  static DayTime? fromMinutesOrNull(int? minutes) =>
      minutes == null ? null : fromMinutes(minutes);

  /// `h:mm AM/PM`, matching the paper sheets.
  String get label {
    final period = hour < 12 ? 'AM' : 'PM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  bool operator ==(Object other) =>
      other is DayTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

extension DayTimeFormat on DayTime? {
  String get labelOrDash => this?.label ?? '-';
}

/// Common surface every log record exposes so [LogRecordRepository] and the
/// list screens can treat the four types uniformly. Concrete fields live on
/// the individual `*Record` classes.
abstract interface class LogRecord {
  /// Firestore document id — empty string for a record not yet saved.
  String get id;

  LogType get logType;

  /// Date only (no time-of-day component).
  DateTime get date;

  /// Sort key within a day, ascending — minutes since midnight of the
  /// record's primary time (start/first reading), or 0 if it has none.
  int get timeSortKey;

  String get locationId;
  String get locationName;

  /// Who recorded it (initials or name).
  String get initials;

  DateTime? get createdAt;
  DateTime? get updatedAt;

  /// Field values only — `id` is the document id, not part of the body;
  /// `createdAt`/`updatedAt` are stamped by the repository.
  Map<String, dynamic> toMap();
}

String logRecordDateLabel(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.day.toString().padLeft(2, '0')}/${date.year}';

/// Shared parsing helpers for the record `fromMap` factories.
DateTime logRecordDateFromMap(Map<String, dynamic> data) =>
    DateTime.fromMillisecondsSinceEpoch(data['dateMillis'] as int);

DateTime? logRecordDateTimeFromMap(Map<String, dynamic> data, String key) {
  final ms = data[key] as int?;
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

DateTime? logRecordTimestampFromMap(Map<String, dynamic> data, String key) {
  final ms = data[key] as int?;
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}
