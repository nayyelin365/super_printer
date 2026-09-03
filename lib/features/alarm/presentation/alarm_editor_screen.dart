import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/alarm_sound.dart';
import 'alarm_controller.dart';
import 'widgets/repeat_days_selector.dart';
import 'widgets/sound_picker.dart';

/// Routed at `/alarms/editor` - create or edit an alarm, driven by
/// [editingAlarmProvider] (null means "creating a new alarm", mirroring
/// how the template builder uses `editingTemplateProvider`).
class AlarmEditorScreen extends ConsumerStatefulWidget {
  const AlarmEditorScreen({super.key});

  @override
  ConsumerState<AlarmEditorScreen> createState() => _AlarmEditorScreenState();
}

class _AlarmEditorScreenState extends ConsumerState<AlarmEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late int _hour;
  late int _minute;
  late String _title;
  late String _note;
  late bool _enabled;
  late Set<int> _repeatDays;
  late String _soundId;
  late bool _repeatSound;
  bool _isSaving = false;

  bool get _isEditing => ref.read(editingAlarmProvider) != null;

  @override
  void initState() {
    super.initState();
    final editing = ref.read(editingAlarmProvider);
    final now = TimeOfDay.now();
    _hour = editing?.hour ?? now.hour;
    _minute = editing?.minute ?? now.minute;
    _title = editing?.title ?? '';
    _note = editing?.note ?? '';
    _enabled = editing?.enabled ?? true;
    _repeatDays = {...(editing?.repeatDays ?? const <int>{})};
    _soundId = editing?.soundId ?? defaultAlarmSoundId;
    _repeatSound = editing?.repeatSound ?? false;

    // A new alarm starts pre-selected with whatever sound was last saved
    // (see `AlarmStorage.loadDefaultSoundId`), not always "Default" — an
    // editing alarm keeps its own already-set sound instead.
    if (editing == null) {
      ref.read(alarmStorageProvider).loadDefaultSoundId().then((soundId) {
        if (mounted) setState(() => _soundId = soundId);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final controller = ref.read(alarmControllerProvider.notifier);
    await ref.read(alarmStorageProvider).saveDefaultSoundId(_soundId);
    final granted = await controller.ensurePermissions();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are disabled for this app, so this alarm may not go off. '
            'Enable notifications in system settings.',
          ),
        ),
      );
    }

    final editing = ref.read(editingAlarmProvider);
    if (editing == null) {
      await controller.addAlarm(
        hour: _hour,
        minute: _minute,
        title: _title.trim(),
        note: _note.trim(),
        enabled: _enabled,
        repeatDays: _repeatDays,
        soundId: _soundId,
        repeatSound: _repeatSound,
      );
    } else {
      await controller.updateAlarm(
        editing.id,
        hour: _hour,
        minute: _minute,
        title: _title.trim(),
        note: _note.trim(),
        enabled: _enabled,
        repeatDays: _repeatDays,
        soundId: _soundId,
        repeatSound: _repeatSound,
      );
    }

    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final editing = ref.read(editingAlarmProvider);
    if (editing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Alarm?'),
          content: const Text('This can\'t be undone.'),
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
      await ref.read(alarmControllerProvider.notifier).deleteAlarm(editing.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = TimeOfDay(hour: _hour, minute: _minute).format(context);

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
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  Text(
                    _isEditing ? 'Edit Alarm' : 'Create Alarm',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    IconButton(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                      tooltip: 'Delete',
                    ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: Text(_isSaving ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: OutlinedButton(
                              onPressed: _pickTime,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                timeLabel,
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          TextFormField(
                            initialValue: _title,
                            decoration: const InputDecoration(labelText: 'Title'),
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (v) => _title = v,
                            validator: (value) => (value == null || value.trim().isEmpty)
                                ? 'Enter a title'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            initialValue: _note,
                            decoration: const InputDecoration(
                              labelText: 'Note (optional)',
                              hintText: 'e.g. Morning exercise',
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (v) => _note = v,
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              const Expanded(
                                child: Text('Enabled', style: TextStyle(fontSize: 14)),
                              ),
                              Switch(
                                value: _enabled,
                                onChanged: (v) => setState(() => _enabled = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          const Text(
                            'REPEAT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RepeatDaysSelector(
                            selected: _repeatDays,
                            onChanged: (days) => setState(() => _repeatDays = days),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _repeatDays.isEmpty
                                ? 'No days selected: this alarm fires once, then turns off.'
                                : 'Repeats every week on the selected day(s).',
                            style: const TextStyle(fontSize: 12, color: Colors.black45),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'SOUND',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black45,
                            ),
                          ),
                          SoundPicker(
                            selectedId: _soundId,
                            onChanged: (id) => setState(() => _soundId = id),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Repeat Sound', style: TextStyle(fontSize: 14)),
                              ),
                              Switch(
                                value: _repeatSound,
                                onChanged: (v) => setState(() => _repeatSound = v),
                              ),
                            ],
                          ),
                          Text(
                            'Keeps re-alerting until you tap Dismiss or Snooze, instead of '
                            'sounding once.',
                            style: const TextStyle(fontSize: 12, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
