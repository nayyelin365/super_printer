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

/// Routed at `/logs/sushiBarTemp` — history of the Sushi Bar Temp Log.
/// One column per unit (Display Case, Cooler, Freezer, or whatever units
/// the shared `logLocationsProvider` list currently has) rather than a
/// fixed three — see `SushiBarTempFormScreen`'s doc comment.
class SushiBarTempLogScreen extends ConsumerWidget {
  const SushiBarTempLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(logLocationsProvider).valueOrNull ?? const [];

    return LogListView<SushiBarTempRecord>(
      logType: LogType.sushiBarTemp,
      columns: [
        LogColumn('Date', (r) => r.dateLabel),
        LogColumn('Time', (r) => r.timeSlot.label, narrow: true),
        for (final location in locations)
          LogColumn(
            location.name,
            (r) => SushiBarTempRecord.tempLabel(r.readingFor(location.id)?.tempF),
            numeric: true,
            narrow: true,
          ),
        LogColumn(
          'Calibration',
          (r) => r.calibrated == null ? '-' : (r.calibrated! ? 'Yes' : 'No'),
          narrow: true,
        ),
        LogColumn('Initial', (r) => r.initials, narrow: true),
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
      onExportPdf: (records) => shareLogRecordPdf(
        logType: LogType.sushiBarTemp,
        records: records.cast<LogRecord>(),
      ),
      onPrintPdf: (records) => printLogRecordPdf(
        logType: LogType.sushiBarTemp,
        records: records.cast<LogRecord>(),
      ),
    );
  }
}
