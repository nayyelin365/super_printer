import 'log_type.dart';

enum PassFail {
  pass('PASS'),
  fail('FAIL');

  const PassFail(this.label);
  final String label;
}

/// One row of a kitchen log sheet. The same shape backs all six
/// [LogType]s; food/location are snapshotted (name + resolved value) at
/// creation time rather than referenced live, so an old entry keeps
/// reading correctly even if that food is later renamed/removed or its
/// target temperature changes — see `LogController.addEntry`.
class LogEntry {
  const LogEntry({
    required this.id,
    required this.logType,
    required this.date,
    required this.hour,
    required this.minute,
    required this.foodName,
    this.targetTemp,
    required this.locationId,
    required this.locationName,
    required this.actualTemp,
    required this.passFail,
    this.correctiveAction = '',
    required this.initials,
    this.createdAt,
    this.updatedAt,
  });

  /// Firestore document id — empty string for an entry not yet saved.
  final String id;

  final LogType logType;

  /// Date only (time-of-day components ignored) — [hour]/[minute] carry
  /// the time, matching the `Alarm` model's convention.
  final DateTime date;
  final int hour;
  final int minute;

  final String foodName;

  /// The food's target temperature at the moment this entry was created,
  /// or null if the food had none set. A snapshot, not a live lookup —
  /// see the class doc.
  final double? targetTemp;

  final String locationId;
  final String locationName;

  final double actualTemp;
  final PassFail passFail;

  /// Required whenever [passFail] is [PassFail.fail] — enforced by the
  /// entry form, not by this model.
  final String correctiveAction;

  /// Who logged this entry (initials or name) — see
  /// `LogController.lastUsedInitials` for how this gets remembered
  /// between entries instead of being retyped every time.
  final String initials;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  DateTime get dateTime => DateTime(date.year, date.month, date.day, hour, minute);

  String get timeLabel {
    final period = hour < 12 ? 'AM' : 'PM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String get dateLabel =>
      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';

  String get targetTempLabel => targetTemp == null ? '-' : '${targetTemp!.toStringAsFixed(0)}°F';

  String get actualTempLabel => '${actualTemp.toStringAsFixed(0)}°F';

  String get correctiveActionLabel => correctiveAction.trim().isEmpty ? 'None' : correctiveAction;

  LogEntry copyWith({
    DateTime? date,
    int? hour,
    int? minute,
    String? foodName,
    double? Function()? targetTemp,
    String? locationId,
    String? locationName,
    double? actualTemp,
    PassFail? passFail,
    String? correctiveAction,
    String? initials,
  }) {
    return LogEntry(
      id: id,
      logType: logType,
      date: date ?? this.date,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      foodName: foodName ?? this.foodName,
      targetTemp: targetTemp != null ? targetTemp() : this.targetTemp,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      actualTemp: actualTemp ?? this.actualTemp,
      passFail: passFail ?? this.passFail,
      correctiveAction: correctiveAction ?? this.correctiveAction,
      initials: initials ?? this.initials,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory LogEntry.fromMap(String id, Map<String, dynamic> data) {
    final dateMs = data['dateMillis'] as int;
    return LogEntry(
      id: id,
      logType: LogType.values.byName(data['logType'] as String),
      date: DateTime.fromMillisecondsSinceEpoch(dateMs),
      hour: data['hour'] as int,
      minute: data['minute'] as int,
      foodName: data['foodName'] as String,
      targetTemp: (data['targetTemp'] as num?)?.toDouble(),
      locationId: data['locationId'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      actualTemp: (data['actualTemp'] as num).toDouble(),
      passFail: PassFail.values.byName(data['passFail'] as String),
      correctiveAction: data['correctiveAction'] as String? ?? '',
      initials: data['initials'] as String? ?? '',
      createdAt: (data['createdAtMillis'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAtMillis'] as int)
          : null,
      updatedAt: (data['updatedAtMillis'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(data['updatedAtMillis'] as int)
          : null,
    );
  }

  /// Field values only — `id` is the Firestore document id, not stored in
  /// the document body. `createdAt`/`updatedAt` are set by the repository
  /// (server timestamps), not by this method.
  Map<String, dynamic> toMap() {
    return {
      'logType': logType.id,
      'dateMillis': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
      'hour': hour,
      'minute': minute,
      'foodName': foodName,
      if (targetTemp != null) 'targetTemp': targetTemp,
      'locationId': locationId,
      'locationName': locationName,
      'actualTemp': actualTemp,
      'passFail': passFail.name,
      'correctiveAction': correctiveAction,
      'initials': initials,
    };
  }
}
