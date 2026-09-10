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

/// One reading on the "Sushi Bar Temp Log" — a single date + time slot,
/// with the Display Case / Cooler / Freezer temperatures, whether the
/// thermometer was calibrated, and the recorder's initial.
class SushiBarTempRecord implements LogRecord {
  const SushiBarTempRecord({
    required this.id,
    required this.date,
    required this.locationId,
    required this.locationName,
    required this.timeSlot,
    this.displayCaseTempF,
    this.coolerTempF,
    this.freezerTempF,
    this.calibrated = false,
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

  final TempTimeSlot timeSlot;
  final double? displayCaseTempF;
  final double? coolerTempF;
  final double? freezerTempF;
  final bool calibrated;

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

  static String tempLabel(double? f) => f == null ? '-' : '${f.toStringAsFixed(0)}°F';

  SushiBarTempRecord copyWith({
    DateTime? date,
    String? locationId,
    String? locationName,
    TempTimeSlot? timeSlot,
    double? Function()? displayCaseTempF,
    double? Function()? coolerTempF,
    double? Function()? freezerTempF,
    bool? calibrated,
    String? initials,
  }) {
    return SushiBarTempRecord(
      id: id,
      date: date ?? this.date,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      timeSlot: timeSlot ?? this.timeSlot,
      displayCaseTempF: displayCaseTempF != null ? displayCaseTempF() : this.displayCaseTempF,
      coolerTempF: coolerTempF != null ? coolerTempF() : this.coolerTempF,
      freezerTempF: freezerTempF != null ? freezerTempF() : this.freezerTempF,
      calibrated: calibrated ?? this.calibrated,
      initials: initials ?? this.initials,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory SushiBarTempRecord.fromMap(String id, Map<String, dynamic> data) {
    return SushiBarTempRecord(
      id: id,
      date: logRecordDateFromMap(data),
      locationId: data['locationId'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      timeSlot: TempTimeSlot.values.byName(data['timeSlot'] as String? ?? 'nineAm'),
      displayCaseTempF: (data['displayCaseTempF'] as num?)?.toDouble(),
      coolerTempF: (data['coolerTempF'] as num?)?.toDouble(),
      freezerTempF: (data['freezerTempF'] as num?)?.toDouble(),
      calibrated: data['calibrated'] as bool? ?? false,
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
      'timeSlot': timeSlot.name,
      if (displayCaseTempF != null) 'displayCaseTempF': displayCaseTempF,
      if (coolerTempF != null) 'coolerTempF': coolerTempF,
      if (freezerTempF != null) 'freezerTempF': freezerTempF,
      'calibrated': calibrated,
      'initials': initials,
    };
  }
}
