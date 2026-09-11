import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/log_record.dart';
import '../domain/log_type.dart';
import '../domain/rice_hot_hold_record.dart';
import 'export/log_record_excel.dart';
import 'export/log_record_pdf.dart';
import 'log_record_controller.dart';
import 'widgets/log_form_fields.dart';
import 'widgets/log_list_view.dart';

/// Routed at `/logs/riceHotHold` — history of the Rice Hot Holding Log
/// (+2 / +4 / +6 / +8 hour temperature checks).
class RiceHotHoldLogScreen extends ConsumerWidget {
  const RiceHotHoldLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LogListView<RiceHotHoldRecord>(
      logType: LogType.riceHotHold,
      columns: [
        LogColumn('Food Item', (r) => r.foodItemName),
        LogColumn('Batch No', (r) => r.batchNo),
        LogColumn('Start', (r) => r.start == null ? '-' : logFormDateTimeFormat.format(r.start!)),
        LogColumn('Actual Temp', (r) => RiceHotHoldRecord.tempLabel(r.actualTempF), numeric: true, narrow: true),
        for (final h in riceHotHoldOffsets) ...[
          LogColumn('+$h hr Time', (r) => r.checkAt(h).time.labelOrDash, narrow: true),
          LogColumn('+$h hr Temp', (r) => RiceHotHoldRecord.tempLabel(r.checkAt(h).tempF), numeric: true, narrow: true),
          LogColumn('+$h hr Init.', (r) => r.checkAt(h).initials, narrow: true),
        ],
        LogColumn('Finished Time', (r) => r.finishedTime.labelOrDash, narrow: true),
        LogColumn('Discard Time', (r) => r.discardTime.labelOrDash, narrow: true),
        LogColumn('Corrective Action', (r) => r.correctiveActionLabel),
        LogColumn('Initial', (r) => r.initials, narrow: true),
      ],
      onAdd: () {
        ref.read(editingLogRecordProvider.notifier).state = null;
        context.push('/logs/riceHotHold/entry');
      },
      onEdit: (record) {
        ref.read(editingLogRecordProvider.notifier).state = record;
        context.push('/logs/riceHotHold/entry');
      },
      onExportExcel: (records) => shareLogRecordExcel(
        logType: LogType.riceHotHold,
        records: records.cast<LogRecord>(),
      ),
      onExportPdf: (records) => shareLogRecordPdf(
        logType: LogType.riceHotHold,
        records: records.cast<LogRecord>(),
      ),
      onPrintPdf: (records) => printLogRecordPdf(
        logType: LogType.riceHotHold,
        records: records.cast<LogRecord>(),
      ),
    );
  }
}
