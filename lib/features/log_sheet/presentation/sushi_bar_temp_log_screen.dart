import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/log_record.dart';
import '../domain/log_type.dart';
import '../domain/sushi_bar_temp_record.dart';
import 'export/log_record_excel.dart';
import 'export/log_record_pdf.dart';
import 'log_record_controller.dart';
import 'widgets/log_list_view.dart';

/// Routed at `/logs/sushiBarTemp` — history of the Sushi Bar Temp Log
/// (Display Case / Cooler / Freezer readings at 9am / 12pm / 3pm / 6pm).
class SushiBarTempLogScreen extends ConsumerWidget {
  const SushiBarTempLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LogListView<SushiBarTempRecord>(
      logType: LogType.sushiBarTemp,
      columns: [
        LogColumn('Date', (r) => r.dateLabel),
        LogColumn('Time', (r) => r.timeSlot.label),
        LogColumn('Display Case', (r) => SushiBarTempRecord.tempLabel(r.displayCaseTempF), numeric: true),
        LogColumn('Cooler', (r) => SushiBarTempRecord.tempLabel(r.coolerTempF), numeric: true),
        LogColumn('Freezer', (r) => SushiBarTempRecord.tempLabel(r.freezerTempF), numeric: true),
        LogColumn('Calibration', (r) => r.calibrated ? 'Yes' : 'No'),
        LogColumn('Initial', (r) => r.initials),
      ],
      onAdd: () {
        ref.read(editingLogRecordProvider.notifier).state = null;
        context.push('/logs/sushiBarTemp/entry');
      },
      onEdit: (record) {
        ref.read(editingLogRecordProvider.notifier).state = record;
        context.push('/logs/sushiBarTemp/entry');
      },
      onExportExcel: (records) => shareLogRecordExcel(
        logType: LogType.sushiBarTemp,
        records: records.cast<LogRecord>(),
      ),
      onExportPdf: (records) => printLogRecordPdf(
        logType: LogType.sushiBarTemp,
        records: records.cast<LogRecord>(),
      ),
    );
  }
}
