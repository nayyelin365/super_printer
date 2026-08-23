import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/alarm.dart';

/// One row in the alarm list, matching a phone Clock app: time + on/off on
/// top, title below, repeat-day summary underneath.
class AlarmCard extends StatelessWidget {
  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Alarm alarm;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dimmed = !alarm.enabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarm.timeLabel,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: dimmed ? Colors.black38 : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alarm.title.trim().isEmpty ? 'Alarm' : alarm.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: dimmed ? Colors.black38 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alarm.repeatLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: dimmed ? Colors.black26 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(value: alarm.enabled, onChanged: onToggle),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}
