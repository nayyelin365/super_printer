import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/log_record.dart';
import '../../domain/log_type.dart';
import '../log_record_controller.dart';

/// One spreadsheet column for a log's history table.
class LogColumn<T extends LogRecord> {
  const LogColumn(this.label, this.value, {this.numeric = false});
  final String label;
  final String Function(T record) value;
  final bool numeric;
}

/// Shared history screen for all four logs — a sticky header (back / title /
/// Add / Export Excel / Export PDF) over a horizontally-scrollable
/// `DataTable`, one row per saved record (newest first, already sorted by
/// the repository). Tap a row to edit; trailing icon deletes with a
/// confirm. "Excel format" for printing is the export, not the on-screen
/// layout (which stays plain rows).
class LogListView<T extends LogRecord> extends ConsumerWidget {
  const LogListView({
    super.key,
    required this.logType,
    required this.columns,
    required this.onAdd,
    required this.onEdit,
    required this.onExportExcel,
    required this.onExportPdf,
  });

  final LogType logType;
  final List<LogColumn<T>> columns;
  final VoidCallback onAdd;
  final void Function(T record) onEdit;
  final void Function(List<T> records) onExportExcel;
  final void Function(List<T> records) onExportPdf;

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
                      (records) => onExportExcel(records.cast<T>()),
                    ),
                    icon: const Icon(Icons.grid_on_outlined),
                    tooltip: 'Export Excel',
                  ),
                  IconButton(
                    onPressed: () => recordsAsync.whenData(
                      (records) => onExportPdf(records.cast<T>()),
                    ),
                    icon: const Icon(Icons.print_outlined),
                    tooltip: 'Export / Print PDF',
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(AppTheme.surface),
          border: TableBorder.all(color: AppTheme.border),
          columns: [
            for (final column in columns)
              DataColumn(label: Text(column.label), numeric: column.numeric),
            const DataColumn(label: Text('')),
          ],
          rows: [
            for (final record in records)
              DataRow(
                onSelectChanged: (_) => onEdit(record),
                cells: [
                  for (final column in columns) DataCell(Text(column.value(record))),
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
