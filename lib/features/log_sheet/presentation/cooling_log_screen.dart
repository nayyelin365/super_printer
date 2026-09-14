import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/cooling_record.dart';
import '../domain/log_record.dart';
import '../domain/log_type.dart';
import 'export/log_record_excel.dart';
import 'export/log_record_pdf.dart';
import 'log_record_controller.dart';
import 'widgets/log_form_fields.dart';
import 'widgets/log_list_view.dart';

/// Routed at `/logs/cooling` — history of the two-stage Cooling Log.
class CoolingLogScreen extends ConsumerWidget {
  const CoolingLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LogListView<CoolingRecord>(
      logType: LogType.cooling,
      columns: [
        LogColumn('Food Item', (r) => r.foodItemName),
        LogColumn('Batch No', (r) => r.batchNo),
        LogColumn('Cooling Start', (r) => r.coolingStart == null ? '-' : logFormDateTimeFormat.format(r.coolingStart!)),
        LogColumn('Initial Temp', (r) => CoolingRecord.tempLabel(r.initialTempF), numeric: true, narrow: true),
        LogColumn('Employee Initial', (r) => r.initialTempInitials, narrow: true),
        LogColumn('Stage 1 Time', (r) => r.stage1Time.labelOrDash, narrow: true),
        LogColumn('Stage 1 Temp', (r) => CoolingRecord.tempLabel(r.stage1TempF), numeric: true, narrow: true),
        LogColumn('Stage 1 Initial', (r) => r.stage1Initials, narrow: true),
        LogColumn('Stage 2 Time', (r) => r.stage2Time.labelOrDash, narrow: true),
        LogColumn('Stage 2 Temp', (r) => CoolingRecord.tempLabel(r.stage2TempF), numeric: true, narrow: true),
        LogColumn('Stage 2 Initial', (r) => r.stage2Initials, narrow: true),
        LogColumn('Corrective Action', (r) => r.correctiveActionLabel),
        LogColumn('Initial', (r) => r.initials, narrow: true),
      ],
      onAdd: () {
        ref.read(editingLogRecordProvider.notifier).state = null;
        context.push('/logs/cooling/entry');
      },
      onEdit: (record) {
        ref.read(editingLogRecordProvider.notifier).state = record;
        context.push('/logs/cooling/entry');
      },
      onExportExcel: (records) => shareLogRecordExcel(
        logType: LogType.cooling,
        records: records.cast<LogRecord>(),
      ),
      onExportPdf: (records) => shareLogRecordPdf(
        logType: LogType.cooling,
        records: records.cast<LogRecord>(),
      ),
      onPrintPdf: (records) => printLogRecordPdf(
        logType: LogType.cooling,
        records: records.cast<LogRecord>(),
      ),
    );
  }
}
