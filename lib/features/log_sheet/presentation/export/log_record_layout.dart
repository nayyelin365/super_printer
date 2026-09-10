import '../../domain/cooling_record.dart';
import '../../domain/log_record.dart';
import '../../domain/log_type.dart';
import '../../domain/rice_hot_hold_record.dart';
import '../../domain/sushi_bar_temp_record.dart';
import '../../domain/sushi_rice_ph_record.dart';

/// A flat, export-ready view of one log's records — the single source both
/// the Excel and the PDF exporters render, so the two always match. Pivot
/// logs (Sushi Rice pH, Sushi Bar Temp) put field names in the first column
/// and one record per column, mirroring the paper form; the other two are
/// plain one-row-per-record tables.
class LogExportLayout {
  LogExportLayout({
    required this.title,
    required this.infoLines,
    required this.headers,
    required this.rows,
  });

  final String title;
  final List<String> infoLines;
  final List<String> headers;
  final List<List<String>> rows;

  String get fileStem => title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
}

String _yesNo(bool v) => v ? 'Yes' : 'No';
String _dt(DateTime? d) => d == null
    ? ''
    : '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year} '
        '${_time12(d.hour, d.minute)}';
String _time12(int h, int m) {
  final period = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

List<String> _infoLines(LogType logType, List<LogRecord> records) {
  final year = records.isEmpty ? DateTime.now().year : records.first.date.year;
  final stores = records.map((r) => r.locationName).where((n) => n.isNotEmpty).toSet();
  return [
    'Year - $year',
    'Store / Location - ${stores.isEmpty ? '' : stores.join(', ')}',
  ];
}

LogExportLayout buildLogExportLayout(LogType logType, List<LogRecord> records) {
  return switch (logType) {
    LogType.sushiRicePh => _sushiRicePhLayout(records.cast<SushiRicePhRecord>()),
    LogType.sushiBarTemp => _sushiBarTempLayout(records.cast<SushiBarTempRecord>()),
    LogType.cooling => _coolingLayout(records.cast<CoolingRecord>()),
    LogType.riceHotHold => _riceHotHoldLayout(records.cast<RiceHotHoldRecord>()),
  };
}

/// Field label + value-getter, for the pivot layouts.
typedef _Field<T> = (String, String Function(T));

LogExportLayout _pivot<T extends LogRecord>(
  LogType logType,
  List<T> records,
  List<String> columnHeaders,
  List<_Field<T>> fields,
) {
  return LogExportLayout(
    title: logType.label,
    infoLines: _infoLines(logType, records),
    headers: ['', ...columnHeaders],
    rows: [
      for (final field in fields)
        [field.$1, for (final record in records) field.$2(record)],
    ],
  );
}

LogExportLayout _sushiRicePhLayout(List<SushiRicePhRecord> records) {
  return _pivot<SushiRicePhRecord>(
    LogType.sushiRicePh,
    records,
    [for (final r in records) r.dateLabel],
    [
      ('pH Meter Calibrated', (r) => _yesNo(r.phMeterCalibrated)),
      ('Rice Batch No.', (r) => r.riceBatchNo),
      ('Time Rice Start Cooking', (r) => r.timeStartCooking.labelOrDash),
      ('Time Rice Cooked', (r) => r.timeCooked.labelOrDash),
      ('Time Acidified', (r) => r.timeAcidified.labelOrDash),
      ('Rice pH', (r) => r.ricePhLabel),
      ('Results in range (4.1, max 4.2)?', (r) => _yesNo(r.inRange)),
      ('pH after Corrected', (r) => r.phAfterCorrectedLabel),
      ('Amount Adding More Vinegar', (r) => r.amountAddingVinegar),
      ('Results in range after correction?', (r) => _yesNo(r.inRangeAfterCorrection)),
      ('Discard out of Range pH Rice', (r) => _yesNo(r.discardOutOfRangeRice)),
      ('Time Rice is all Used', (r) => r.timeRiceAllUsed.labelOrDash),
      ('Discard Time after Expiry', (r) => r.discardTimeAfterExpiry.labelOrDash),
      ("Tester's Initial", (r) => r.initials),
    ],
  );
}

LogExportLayout _sushiBarTempLayout(List<SushiBarTempRecord> records) {
  return _pivot<SushiBarTempRecord>(
    LogType.sushiBarTemp,
    records,
    [for (final r in records) '${r.dateLabel}\n${r.timeSlot.label}'],
    [
      ('Display Case', (r) => SushiBarTempRecord.tempLabel(r.displayCaseTempF)),
      ('Cooler', (r) => SushiBarTempRecord.tempLabel(r.coolerTempF)),
      ('Freezer', (r) => SushiBarTempRecord.tempLabel(r.freezerTempF)),
      ('Calibration', (r) => _yesNo(r.calibrated)),
      ('Initial', (r) => r.initials),
    ],
  );
}

LogExportLayout _coolingLayout(List<CoolingRecord> records) {
  return LogExportLayout(
    title: LogType.cooling.label,
    infoLines: _infoLines(LogType.cooling, records),
    headers: const [
      'Food Item Name',
      'Batch No',
      'Cooling Start',
      'Initial Temp',
      'Stage 1 Time (135°F → 70°F ≤ 2 hr)',
      'Stage 1 Temp',
      'Stage 2 Time (≤ 41°F ≤ 6 hr total)',
      'Stage 2 Temp',
      'Corrective Action',
      'Initial',
    ],
    rows: [
      for (final r in records)
        [
          r.foodItemName,
          r.batchNo,
          _dt(r.coolingStart),
          CoolingRecord.tempLabel(r.initialTempF),
          r.stage1Time.labelOrDash,
          CoolingRecord.tempLabel(r.stage1TempF),
          r.stage2Time.labelOrDash,
          CoolingRecord.tempLabel(r.stage2TempF),
          r.correctiveActionLabel,
          r.initials,
        ],
    ],
  );
}

LogExportLayout _riceHotHoldLayout(List<RiceHotHoldRecord> records) {
  return LogExportLayout(
    title: LogType.riceHotHold.label,
    infoLines: _infoLines(LogType.riceHotHold, records),
    headers: [
      'Food Item Name',
      'Batch No',
      'Start',
      'Actual Temp °F',
      for (final h in riceHotHoldOffsets) ...['+$h hr Time', '+$h hr Temp', '+$h hr Initial'],
      'Corrective Action',
      'Initial',
    ],
    rows: [
      for (final r in records)
        [
          r.foodItemName,
          r.batchNo,
          _dt(r.start),
          RiceHotHoldRecord.tempLabel(r.actualTempF),
          for (final h in riceHotHoldOffsets) ...[
            r.checkAt(h).time.labelOrDash,
            RiceHotHoldRecord.tempLabel(r.checkAt(h).tempF),
            r.checkAt(h).initials,
          ],
          r.correctiveActionLabel,
          r.initials,
        ],
    ],
  );
}
