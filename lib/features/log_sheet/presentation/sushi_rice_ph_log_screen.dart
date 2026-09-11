import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/log_record.dart';
import '../domain/log_type.dart';
import '../domain/sushi_rice_ph_record.dart';
import 'export/log_record_excel.dart';
import 'export/log_record_pdf.dart';
import 'log_record_controller.dart';
import 'widgets/log_list_view.dart';

/// Routed at `/logs/sushiRicePh` — history of the standalone daily Sushi
/// Rice pH form (unrelated to the guided Sushi Rice Preparation SOP).
class SushiRicePhLogScreen extends ConsumerWidget {
  const SushiRicePhLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LogListView<SushiRicePhRecord>(
      logType: LogType.sushiRicePh,
      columns: [
        LogColumn('Date', (r) => r.dateLabel),
        LogColumn('Batch No.', (r) => r.riceBatchNo),
        LogColumn('Meter Calibrated', (r) => r.phMeterCalibrated ? 'Yes' : 'No'),
        LogColumn('Start Cooking', (r) => r.timeStartCooking.labelOrDash),
        LogColumn('Cooked', (r) => r.timeCooked.labelOrDash),
        LogColumn('Acidified', (r) => r.timeAcidified.labelOrDash),
        LogColumn('Rice pH', (r) => r.ricePhLabel, numeric: true),
        LogColumn('In Range?', (r) => r.inRange ? 'Yes' : 'No'),
        LogColumn('pH After Correction', (r) => r.phAfterCorrectedLabel),
        LogColumn('In Range After?', (r) => r.inRangeAfterCorrection ? 'Yes' : 'No'),
        LogColumn('Discarded?', (r) => r.discardOutOfRangeRice ? 'Yes' : 'No'),
        LogColumn('All Used', (r) => r.timeRiceAllUsed.labelOrDash),
        LogColumn('Discard After Expiry', (r) => r.discardTimeAfterExpiry.labelOrDash),
        LogColumn('Tester', (r) => r.initials),
      ],
      onAdd: () {
        ref.read(editingLogRecordProvider.notifier).state = null;
        context.push('/logs/sushiRicePh/entry');
      },
      onEdit: (record) {
        ref.read(editingLogRecordProvider.notifier).state = record;
        context.push('/logs/sushiRicePh/entry');
      },
      onExportExcel: (records) => shareLogRecordExcel(
        logType: LogType.sushiRicePh,
        records: records.cast<LogRecord>(),
      ),
      onExportPdf: (records) => shareLogRecordPdf(
        logType: LogType.sushiRicePh,
        records: records.cast<LogRecord>(),
      ),
      onPrintPdf: (records) => printLogRecordPdf(
        logType: LogType.sushiRicePh,
        records: records.cast<LogRecord>(),
      ),
    );
  }
}
