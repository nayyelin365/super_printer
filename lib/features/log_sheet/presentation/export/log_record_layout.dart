import '../../domain/cooling_record.dart';
import '../../domain/log_record.dart';
import '../../domain/log_type.dart';
import '../../domain/rice_hot_hold_record.dart';
import '../../domain/sushi_bar_temp_record.dart';
import '../../domain/sushi_rice_ph_record.dart';

/// A flat, export-ready view of one log's records — the single source both
/// the Excel and the PDF exporters render, so the two always match. Every
/// log is a plain one-row-per-record table (fields across as columns, one
/// record per row) rather than a pivot with one column per record — a
/// column-per-record layout stops being printable/readable once a log has
/// dozens or hundreds of entries; a row-per-record table just grows down
/// the page instead of sideways off it.
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

String _yesNo(bool? v) => v == null ? '-' : (v ? 'Yes' : 'No');
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
  return [
    'Year - $year',
    'Store Name - $logStoreName',
    'Location - $logStoreLocation',
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

LogExportLayout _sushiRicePhLayout(List<SushiRicePhRecord> records) {
  return LogExportLayout(
    title: LogType.sushiRicePh.label,
    infoLines: _infoLines(LogType.sushiRicePh, records),
    headers: const [
      'Date',
      'pH Meter Calibrated',
      'Rice Batch No.',
      'Time Rice Start Cooking',
      'Time Rice Cooked',
      'Time Acidified',
      'Rice pH',
      'Results in range (4.1, max 4.2)?',
      'pH after Corrected',
      'Amount Adding More Vinegar',
      'Results in range after correction?',
      'Discard out of Range pH Rice',
      'Time Rice is all Used',
      'Discard Time after Expiry',
      "Tester's Initial",
    ],
    rows: [
      for (final r in records)
        [
          r.dateLabel,
          _yesNo(r.phMeterCalibrated),
          r.riceBatchNo,
          r.timeStartCooking.labelOrDash,
          r.timeCooked.labelOrDash,
          r.timeAcidified.labelOrDash,
          r.ricePhLabel,
          _yesNo(r.inRange),
          r.phAfterCorrectedLabel,
          r.amountAddingVinegar,
          _yesNo(r.inRangeAfterCorrection),
          _yesNo(r.discardOutOfRangeRice),
          _dt(r.timeRiceAllUsed),
          r.discardTimeAfterExpiry.labelOrDash,
          r.initials,
        ],
    ],
  );
}

LogExportLayout _sushiBarTempLayout(List<SushiBarTempRecord> records) {
  // Units aren't fixed columns (Display Case/Cooler/Freezer) any more — one
  // column per unit that actually appears somewhere in these records,
  // ordered by first appearance.
  final units = <String, String>{}; // locationId -> locationName
  for (final r in records) {
    for (final reading in r.readings) {
      units.putIfAbsent(reading.locationId, () => reading.locationName);
    }
  }

  return LogExportLayout(
    title: LogType.sushiBarTemp.label,
    infoLines: _infoLines(LogType.sushiBarTemp, records),
    headers: [
      'Date',
      'Time',
      for (final name in units.values) name,
      'Calibration',
      'Initial',
    ],
    rows: [
      for (final r in records)
        [
          r.dateLabel,
          r.timeSlot.label,
          for (final id in units.keys) SushiBarTempRecord.tempLabel(r.readingFor(id)?.tempF),
          _yesNo(r.calibrated),
          r.initials,
        ],
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
      'Employee Initial',
      'Stage 1 Time (135°F -> 70°F <= 2 hr)',
      'Stage 1 Temp',
      'Stage 1 Initial',
      'Stage 2 Time (<= 41°F, <= 6 hr total)',
      'Stage 2 Temp',
      'Stage 2 Initial',
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
          r.initialTempInitials,
          r.stage1Time.labelOrDash,
          CoolingRecord.tempLabel(r.stage1TempF),
          r.stage1Initials,
          r.stage2Time.labelOrDash,
          CoolingRecord.tempLabel(r.stage2TempF),
          r.stage2Initials,
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
      'Start Initial',
      for (final h in riceHotHoldOffsets) ...['+$h hr Time', '+$h hr Temp', '+$h hr Initial'],
      'Finished Time',
      'Discard Time',
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
          r.startInitials,
          for (final h in riceHotHoldOffsets) ...[
            r.checkAt(h).time.labelOrDash,
            RiceHotHoldRecord.tempLabel(r.checkAt(h).tempF),
            r.checkAt(h).initials,
          ],
          r.finishedTime.labelOrDash,
          r.discardTime.labelOrDash,
          r.correctiveActionLabel,
          r.initials,
        ],
    ],
  );
}
