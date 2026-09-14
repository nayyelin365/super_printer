import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/log_record.dart';
import '../domain/log_type.dart';
import '../domain/sushi_rice_ph_record.dart';
import 'export/log_record_excel.dart';
import 'export/log_record_pdf.dart';
import 'log_record_controller.dart';
import 'widgets/log_form_fields.dart';
import 'widgets/log_list_view.dart';

String _yn(bool? v) => v == null ? '-' : (v ? 'Yes' : 'No');

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
        LogColumn('Meter Calibrated', (r) => _yn(r.phMeterCalibrated), narrow: true),
        LogColumn('Start Cooking', (r) => r.timeStartCooking.labelOrDash),
        LogColumn('Cooked', (r) => r.timeCooked.labelOrDash),
        LogColumn('Acidified', (r) => r.timeAcidified.labelOrDash),
        LogColumn('Rice pH', (r) => r.ricePhLabel, numeric: true, narrow: true),
        LogColumn('In Range?', (r) => _yn(r.inRange), narrow: true),
        LogColumn('pH After Correction', (r) => r.phAfterCorrectedLabel, numeric: true, narrow: true),
        LogColumn('In Range After?', (r) => _yn(r.inRangeAfterCorrection), narrow: true),
        LogColumn('Discarded?', (r) => _yn(r.discardOutOfRangeRice), narrow: true),
        LogColumn(
          'All Used',
          (r) => r.timeRiceAllUsed == null ? '-' : logFormDateTimeFormat.format(r.timeRiceAllUsed!),
        ),
        LogColumn('Discard After Expiry', (r) => r.discardTimeAfterExpiry.labelOrDash),
        LogColumn('Tester', (r) => r.initials, narrow: true),
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
