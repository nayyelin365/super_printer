import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/log_entry.dart';

/// The log sheet table — Date, Time, Food, Unit Name/Location, Target
/// Temp, Actual Temp, Pass/Fail, Corrective Action, Initials, plus a row
/// actions column. Horizontally scrollable so every column stays readable
/// instead of being squeezed on a narrow window.
class LogEntryTable extends StatelessWidget {
  const LogEntryTable({
    super.key,
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  final List<LogEntry> entries;
  final ValueChanged<LogEntry> onEdit;
  final ValueChanged<LogEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surface),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Food')),
          DataColumn(label: Text('Unit Name / Location')),
          DataColumn(label: Text('Target Temp')),
          DataColumn(label: Text('Actual Temp')),
          DataColumn(label: Text('Pass/Fail')),
          DataColumn(label: Text('Corrective Action')),
          DataColumn(label: Text('Initials')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (final entry in entries)
            DataRow(
              cells: [
                DataCell(Text(entry.dateLabel)),
                DataCell(Text(entry.timeLabel)),
                DataCell(Text(entry.foodName)),
                DataCell(Text(entry.locationName)),
                DataCell(Text(entry.targetTempLabel)),
                DataCell(Text(entry.actualTempLabel)),
                DataCell(_PassFailBadge(entry: entry)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(entry.correctiveActionLabel, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(Text(entry.initials)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => onEdit(entry),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () => onDelete(entry),
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                        tooltip: 'Delete',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PassFailBadge extends StatelessWidget {
  const _PassFailBadge({required this.entry});
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final pass = entry.passFail.name == 'pass';
    final color = pass ? AppTheme.success : AppTheme.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        entry.passFail.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
