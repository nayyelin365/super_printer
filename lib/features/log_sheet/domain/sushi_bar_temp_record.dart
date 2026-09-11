import 'log_record.dart';
import 'log_type.dart';

/// The four fixed reading times on the paper "Sushi Bar Temp Log".
enum TempTimeSlot {
  nineAm('9am', 9),
  noon('12pm', 12),
  threePm('3pm', 15),
  sixPm('6pm', 18);

  const TempTimeSlot(this.label, this.hour24);

  final String label;
  final int hour24;
}

/// One unit's temperature within a [SushiBarTempRecord] — "unit" is
/// whatever the kitchen tracks (Display Case, Cooler, Freezer, or any
/// other one added later), backed by the shared `log_locations`
/// collection (`LogLocationRepository`/`logLocationsProvider`) rather than
/// a fixed set of columns, so a kitchen with 5 units types 5 temperatures
/// and one with 2 types 2 — the form always mirrors whatever units exist
/// today, including ones added on the spot.
class UnitTempReading {
  const UnitTempReading({
    required this.locationId,
    required this.locationName,
    this.tempF,
  });

  final String locationId;
  final String locationName;
  final double? tempF;

  static String tempLabel(double? f) => f == null ? '-' : '${f.toStringAsFixed(0)}°F';

  UnitTempReading copyWith({double? Function()? tempF}) {
    return UnitTempReading(
      locationId: locationId,
      locationName: locationName,
      tempF: tempF != null ? tempF() : this.tempF,
    );
  }

  factory UnitTempReading.fromMap(Map<String, dynamic> data) {
    return UnitTempReading(
      locationId: data['locationId'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      tempF: (data['tempF'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'locationId': locationId,
        'locationName': locationName,
        if (tempF != null) 'tempF': tempF,
      };
}

/// One reading on the "Sushi Bar Temp Log" — a single date + time slot,
/// a temperature per unit ([readings]), whether the thermometer was
/// calibrated, and the recorder's initial.
class SushiBarTempRecord implements LogRecord {
  const SushiBarTempRecord({
    required this.id,
    required this.date,
    required this.timeSlot,
    this.readings = const [],
    this.calibrated,
    this.initials = '',
    this.createdAt,
    this.updatedAt,
  });

  @override
  final String id;
  @override
  final DateTime date;

  final TempTimeSlot timeSlot;

  /// One entry per unit tracked at the time this record was saved — see
  /// the class doc on [UnitTempReading].
  final List<UnitTempReading> readings;

  /// Whether the thermometer was calibrated — null means "not answered
  /// yet" (no default), not "No".
  final bool? calibrated;

  @override
  final String initials;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  LogType get logType => LogType.sushiBarTemp;

  @override
  int get timeSortKey => timeSlot.hour24 * 60;

  String get dateLabel => logRecordDateLabel(date);

  static String tempLabel(double? f) => UnitTempReading.tempLabel(f);

  /// Reading for [locationId], or null if this record has none (a unit
  /// added after this record was saved, for instance).
  UnitTempReading? readingFor(String locationId) =>
      readings.where((r) => r.locationId == locationId).firstOrNull;

  SushiBarTempRecord copyWith({
    DateTime? date,
    TempTimeSlot? timeSlot,
    List<UnitTempReading>? readings,
    bool? Function()? calibrated,
    String? initials,
  }) {
    return SushiBarTempRecord(
      id: id,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      readings: readings ?? this.readings,
      calibrated: calibrated != null ? calibrated() : this.calibrated,
      initials: initials ?? this.initials,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory SushiBarTempRecord.fromMap(String id, Map<String, dynamic> data) {
    final rawReadings = data['readings'] as List<dynamic>? ?? const [];
    return SushiBarTempRecord(
      id: id,
      date: logRecordDateFromMap(data),
      timeSlot: TempTimeSlot.values.byName(data['timeSlot'] as String? ?? 'nineAm'),
      readings: [
        for (final r in rawReadings) UnitTempReading.fromMap(Map<String, dynamic>.from(r as Map)),
      ],
      calibrated: data['calibrated'] as bool?,
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
      'timeSlot': timeSlot.name,
      'readings': [for (final r in readings) r.toMap()],
      if (calibrated != null) 'calibrated': calibrated,
      'initials': initials,
    };
  }
}
