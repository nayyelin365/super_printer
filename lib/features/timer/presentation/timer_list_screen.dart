import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../alarm/domain/alarm_sound.dart';
import '../../alarm/presentation/widgets/sound_picker.dart';
import '../domain/kitchen_timer.dart';
import 'timer_controller.dart';

const _presetMinutes = [1, 5, 10, 15, 20, 30];

/// The "Timers" tab content (embedded in [AlarmHomeScreen]'s bottom nav) —
/// a card grid of running/paused/finished [KitchenTimer]s (comfortably
/// wide for a tablet, not a single mobile-width column) plus a "+" to
/// start a new one via [_NewTimerDialog].
class TimerListScreen extends ConsumerWidget {
  const TimerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timers = ref.watch(timerControllerProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Timers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openNewTimerDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Timer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: timers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 48, color: Colors.black.withValues(alpha: 0.15)),
                        const SizedBox(height: 12),
                        const Text(
                          'No timers yet. Tap New Timer to start one.',
                          style: TextStyle(color: Colors.black45, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: timers.length,
                    itemBuilder: (context, index) => _TimerCard(timer: timers[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNewTimerDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _NewTimerDialog(ref: ref),
    );
  }
}

class _TimerCard extends ConsumerWidget {
  const _TimerCard({required this.timer});

  final KitchenTimer timer;

  Color get _accent {
    if (timer.isFinished) return AppTheme.danger;
    if (timer.isRunning) return AppTheme.amber;
    return Colors.black26;
  }

  double get _progress {
    if (timer.totalDuration == Duration.zero) return 0;
    final fraction = timer.remaining.inMilliseconds / timer.totalDuration.inMilliseconds;
    return fraction.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(timerControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                timer.repeatSound ? Icons.notifications_active_outlined : Icons.timer_outlined,
                size: 16,
                color: Colors.black38,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  timer.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => controller.removeTimer(timer.id),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 18, color: Colors.black38),
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 128,
                      height: 128,
                      child: CircularProgressIndicator(
                        value: timer.isFinished ? 1 : _progress,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        backgroundColor: AppTheme.surface,
                        valueColor: AlwaysStoppedAnimation(_accent),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timer.isFinished ? "Time's up" : timer.remainingLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: timer.isFinished ? 15 : 22,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: timer.isFinished ? AppTheme.danger : AppTheme.navyDark,
                          ),
                        ),
                        if (timer.isPaused) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Paused',
                            style: TextStyle(fontSize: 11, color: Colors.black45),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (timer.isFinished)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => controller.restartTimer(timer.id),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Restart'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => timer.isRunning
                    ? controller.pauseTimer(timer.id)
                    : controller.resumeTimer(timer.id),
                icon: Icon(timer.isRunning ? Icons.pause : Icons.play_arrow, size: 18),
                label: Text(timer.isRunning ? 'Pause' : 'Resume'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  backgroundColor: timer.isRunning ? AppTheme.surface : AppTheme.navyDark,
                  foregroundColor: timer.isRunning ? AppTheme.navyDark : Colors.white,
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NewTimerDialog extends StatefulWidget {
  const _NewTimerDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_NewTimerDialog> createState() => _NewTimerDialogState();
}

class _NewTimerDialogState extends State<_NewTimerDialog> {
  int _hours = 0;
  int _minutes = 5;
  int _seconds = 0;
  String _label = '';
  String _soundId = defaultAlarmSoundId;
  bool _repeatSound = true;
  bool _isStarting = false;

  Duration get _duration => Duration(hours: _hours, minutes: _minutes, seconds: _seconds);

  Future<void> _start() async {
    if (_duration <= Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a duration greater than zero.')),
      );
      return;
    }
    setState(() => _isStarting = true);
    await widget.ref.read(timerControllerProvider.notifier).addTimer(
          _duration,
          label: _label,
          soundId: _soundId,
          repeatSound: _repeatSound,
        );
    if (mounted) Navigator.of(context).pop();
  }

  void _setPreset(int minutes) => setState(() {
        _hours = 0;
        _minutes = minutes;
        _seconds = 0;
      });

  static const _sectionLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Colors.black45,
    letterSpacing: 0.6,
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('New Timer', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DURATION', style: _sectionLabelStyle),
                    const SizedBox(height: 8),
                    _DurationGroup(
                      hours: _hours,
                      minutes: _minutes,
                      seconds: _seconds,
                      onHours: (v) => setState(() => _hours = v),
                      onMinutes: (v) => setState(() => _minutes = v),
                      onSeconds: (v) => setState(() => _seconds = v),
                    ),
                    const SizedBox(height: 18),
                    const Text('PRESETS', style: _sectionLabelStyle),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in _presetMinutes)
                          ChoiceChip(
                            label: Text('$m min'),
                            selected: _hours == 0 && _minutes == m && _seconds == 0,
                            onSelected: (_) => _setPreset(m),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Label (optional)',
                        hintText: 'e.g. Sushi Rice',
                      ),
                      onChanged: (v) => _label = v,
                    ),
                    const SizedBox(height: 18),
                    const Text('SOUND', style: _sectionLabelStyle),
                    SoundPicker(
                      selectedId: _soundId,
                      onChanged: (id) => setState(() => _soundId = id),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Repeat until dismissed', style: TextStyle(fontSize: 14)),
                        ),
                        Switch(
                          value: _repeatSound,
                          onChanged: (v) => setState(() => _repeatSound = v),
                        ),
                      ],
                    ),
                    const Text(
                      'Keeps re-alerting until you dismiss the notification, instead of '
                      'sounding once.',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isStarting ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_isStarting ? 'Starting...' : 'Start Timer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

/// The Hours : Minutes : Seconds picker — one rounded card split into
/// three columns by hairline dividers, instead of three separate boxes.
class _DurationGroup extends StatelessWidget {
  const _DurationGroup({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.onHours,
    required this.onMinutes,
    required this.onSeconds,
  });

  final int hours;
  final int minutes;
  final int seconds;
  final ValueChanged<int> onHours;
  final ValueChanged<int> onMinutes;
  final ValueChanged<int> onSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _DurationColumn(label: 'Hours', value: hours, max: 23, onChanged: onHours),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppTheme.border),
            Expanded(
              child: _DurationColumn(label: 'Minutes', value: minutes, max: 59, onChanged: onMinutes),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppTheme.border),
            Expanded(
              child: _DurationColumn(label: 'Seconds', value: seconds, max: 59, onChanged: onSeconds),
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationColumn extends StatelessWidget {
  const _DurationColumn({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepArrow(
            icon: Icons.keyboard_arrow_up,
            onTap: () => onChanged(value >= max ? 0 : value + 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              value.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
                color: AppTheme.navyDark,
              ),
            ),
          ),
          _StepArrow(
            icon: Icons.keyboard_arrow_down,
            onTap: () => onChanged(value <= 0 ? max : value - 1),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 20, color: AppTheme.navyDark),
      ),
    );
  }
}
