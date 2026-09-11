import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/log_record.dart';
import '../../domain/log_type.dart';
import '../log_record_controller.dart';

enum _ShareFormat { excel, pdf }

/// One spreadsheet column for a log's history table. [narrow] pins the
/// cell to a small fixed width — for columns whose values are always short
/// (Yes/No, a 2-digit reading, an initial) so they don't take the same
/// width as a free-text column like "Corrective Action"; see
/// `_columnWidths` in `log_record_pdf.dart` for the equivalent on the PDF
/// export.
class LogColumn<T extends LogRecord> {
  const LogColumn(this.label, this.value, {this.numeric = false, this.narrow = false});
  final String label;
  final String Function(T record) value;
  final bool numeric;
  final bool narrow;
}

/// Shared history screen for all four logs — a sticky header (back / title /
/// Share / Print / Add) over a horizontally-scrollable `DataTable`, one row
/// per saved record (newest first, already sorted by the repository). Tap
/// a row to edit; trailing icon deletes with a confirm. "Excel format" for
/// printing is the export, not the on-screen layout (which stays plain
/// rows). Share opens a small dialog to pick Excel or PDF; Print is its
/// own separate action (the system print / save-as-PDF dialog).
class LogListView<T extends LogRecord> extends ConsumerWidget {
  const LogListView({
    super.key,
    required this.logType,
    required this.columns,
    required this.onAdd,
    required this.onEdit,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onPrintPdf,
  });

  final LogType logType;
  final List<LogColumn<T>> columns;
  final VoidCallback onAdd;
  final void Function(T record) onEdit;
  final void Function(List<T> records) onExportExcel;

  /// Shares the PDF via the system share sheet.
  final void Function(List<T> records) onExportPdf;

  /// Opens the system print / save-as-PDF dialog instead of sharing.
  final void Function(List<T> records) onPrintPdf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(logRecordsProvider(logType));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.canPop() ? context.pop() : context.go('/logs'),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Text(
                      logType.label,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => recordsAsync.whenData(
                      (records) => _shareRecords(context, records.cast<T>()),
                    ),
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share',
                  ),
                  IconButton(
                    onPressed: () => recordsAsync.whenData(
                      (records) => onPrintPdf(records.cast<T>()),
                    ),
                    icon: const Icon(Icons.print_outlined),
                    tooltip: 'Print',
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: const Icon(Icons.add, size: 18),
                    ),
                    label: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: recordsAsync.when(
                data: (records) {
                  if (records.isEmpty) {
                    return const Center(
                      child: Text(
                        'No entries yet. Tap Add to create one.',
                        style: TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                    );
                  }
                  return _Table<T>(
                    records: records.cast<T>(),
                    columns: columns,
                    onEdit: onEdit,
                    onDelete: (record) => _confirmDelete(context, ref, record),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Could not load ${logType.label}.\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Asks Excel or PDF, then hands [records] to the matching share
  /// callback — one Share entry point instead of two toolbar buttons.
  /// Print (the system print/save-as-PDF dialog) is a separate action.
  Future<void> _shareRecords(BuildContext context, List<T> records) async {
    final choice = await showDialog<_ShareFormat>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Share as'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(_ShareFormat.excel),
            child: const Row(
              children: [
                Icon(Icons.grid_on_outlined, size: 20),
                SizedBox(width: 12),
                Text('Share Excel'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(_ShareFormat.pdf),
            child: const Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 20),
                SizedBox(width: 12),
                Text('Share PDF'),
              ],
            ),
          ),
        ],
      ),
    );

    switch (choice) {
      case _ShareFormat.excel:
        onExportExcel(records);
      case _ShareFormat.pdf:
        onExportPdf(records);
      case null:
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, T record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text('Delete the ${logRecordDateLabel(record.date)} entry? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(logRecordControllerProvider).deleteRecord(record.id);
    }
  }
}

class _Table<T extends LogRecord> extends StatelessWidget {
  const _Table({
    required this.records,
    required this.columns,
    required this.onEdit,
    required this.onDelete,
  });

  final List<T> records;
  final List<LogColumn<T>> columns;
  final void Function(T record) onEdit;
  final void Function(T record) onDelete;

  static const double _narrowWidth = 64;
  static const double _normalWidth = 90;

  /// Every column — narrow or not — wraps onto a second line instead of
  /// truncating with an ellipsis when it doesn't fit; ellipsis only kicks
  /// in as a last resort past 2 lines.
  Widget _wrapped(String text, {required bool narrow}) {
    return SizedBox(
      width: narrow ? _narrowWidth : _normalWidth,
      child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, softWrap: true,style: const TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(AppTheme.surface),
          border: TableBorder.all(color: AppTheme.border),
          // Tight by default (the Flutter defaults — 56/24 — are sized for
          // a handful of wide columns; these tables run a dozen-plus
          // mostly-short ones) so short columns don't inherit padding sized
          // for long free-text ones, and the whole table needs less
          // horizontal scrolling to read.
          columnSpacing: 20,
          horizontalMargin: 12,
          // Tall enough for a narrow column's label/value to wrap onto a
          // second line — wrapping reads better than an ellipsis cutting
          // off a Yes/No or short reading.
          headingRowHeight: 52,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 52,
          columns: [
            for (final column in columns)
              DataColumn(
                label: _wrapped(column.label, narrow: column.narrow),
                numeric: column.numeric,
              ),
            const DataColumn(label: Text('')),
          ],
          rows: [
            for (final record in records)
              DataRow(
                onSelectChanged: (_) => onEdit(record),
                cells: [
                  for (final column in columns)
                    DataCell(_wrapped(column.value(record), narrow: column.narrow)),
                  DataCell(
                    IconButton(
                      onPressed: () => onDelete(record),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Delete',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
