import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/alarm.dart';
import 'alarm_controller.dart';
import 'widgets/alarm_card.dart';

/// Routed at `/alarms` - lists every alarm, similar to a phone Clock app.
class AlarmListScreen extends ConsumerWidget {
  const AlarmListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarms = [...ref.watch(alarmControllerProvider)]
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Alarms',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openEditor(context, ref, null),
                    icon: const Icon(Icons.add),
                    tooltip: 'Add alarm',
                  ),
                ],
              ),
            ),
            Expanded(
              child: alarms.isEmpty
                  ? const Center(
                      child: Text(
                        'No alarms yet. Tap + to add one.',
                        style: TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: alarms.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final alarm = alarms[index];
                        return AlarmCard(
                          alarm: alarm,
                          onToggle: (enabled) async {
                            if (enabled && !await ref
                                .read(alarmControllerProvider.notifier)
                                .ensurePermissions()) {
                              if (context.mounted) _showPermissionDenied(context);
                            }
                            await ref
                                .read(alarmControllerProvider.notifier)
                                .setEnabled(alarm.id, enabled);
                          },
                          onEdit: () => _openEditor(context, ref, alarm),
                          onDelete: () => _confirmDelete(context, ref, alarm),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, Alarm? alarm) {
    ref.read(editingAlarmProvider.notifier).state = alarm;
    context.push('/alarms/editor');
  }

  void _showPermissionDenied(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications are disabled for this app, so this alarm may not go off. '
          'Enable notifications in system settings.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Alarm alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Alarm?'),
          content: Text('Delete the ${alarm.timeLabel} alarm "${alarm.title}"?'),
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
        );
      },
    );
    if (confirmed == true) {
      await ref.read(alarmControllerProvider.notifier).deleteAlarm(alarm.id);
    }
  }
}
