import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../alarm/data/alarm_notifications.dart';
import '../../alarm/domain/alarm.dart' show stableAlarmBaseId;
import '../../alarm/domain/alarm_sound.dart';
import '../../alarm/presentation/alarm_controller.dart' show alarmControllerProvider;
import '../domain/kitchen_timer.dart';

const _uuid = Uuid();

/// Sub-id for a timer's notification, in the same `base * 10 + subId`
/// scheme `NotificationAlarmScheduler` uses for alarms (subIds 1-7 for
/// weekdays, 9 for one-time) — 8 is the one digit that scheme never uses,
/// so a timer's notification id can never collide with a real alarm's.
const _timerSubId = 8;

/// Countdown timers, styled after a phone Clock app's Timers tab. See the
/// class doc on [KitchenTimer] for why each running timer schedules its
/// end-of-timer notification directly (on the Alarms feature's own
/// channels) rather than through [AlarmController].
class TimerController extends StateNotifier<List<KitchenTimer>> {
  TimerController(this._ref) : super(const []) {
    // Redraws every second so each running timer's live countdown (and
    // "did it just hit zero") stays current — a single shared ticker
    // rather than one per timer.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final Ref _ref;
  late final Timer _ticker;

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  int _notificationIdFor(String timerId) => stableAlarmBaseId(timerId) * 10 + _timerSubId;

  void _tick() {
    if (state.isEmpty) return;
    final justFinished = state.where((t) => t.isRunning && t.remaining == Duration.zero);
    if (justFinished.isEmpty) {
      // Nothing changed state, but running timers still need a rebuild to
      // show the new second.
      if (state.any((t) => t.isRunning)) state = [...state];
      return;
    }
    state = [
      for (final t in state)
        justFinished.contains(t)
            ? t.copyWith(endAt: () => null, notificationId: () => null, isFinished: true)
            : t,
    ];
  }

  /// Starts a new timer for [duration]. Requests notification permission
  /// first (reusing the Alarms feature's own request), same as enabling an
  /// alarm — a timer nobody can hear finish isn't worth starting silently.
  Future<KitchenTimer?> addTimer(
    Duration duration, {
    String label = 'Timer',
    String soundId = defaultAlarmSoundId,
    bool repeatSound = false,
  }) async {
    if (duration <= Duration.zero) return null;
    await _ref.read(alarmControllerProvider.notifier).ensurePermissions();

    final trimmedLabel = label.trim().isEmpty ? 'Timer' : label.trim();
    final id = _uuid.v4();
    final notificationId = _notificationIdFor(id);
    final endAt = DateTime.now().add(duration);

    await scheduleOnce(
      id: notificationId,
      title: trimmedLabel,
      body: 'Timer finished',
      at: endAt,
      soundId: soundId,
      repeatSound: repeatSound,
    );

    final timer = KitchenTimer(
      id: id,
      label: trimmedLabel,
      totalDuration: duration,
      soundId: soundId,
      repeatSound: repeatSound,
      endAt: endAt,
      notificationId: notificationId,
    );
    state = [...state, timer];
    return timer;
  }

  Future<void> pauseTimer(String id) async {
    final index = state.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final timer = state[index];
    if (!timer.isRunning) return;

    if (timer.notificationId != null) {
      await cancelNotification(timer.notificationId!);
    }
    final remaining = timer.remaining;
    state = [
      for (final t in state)
        t.id == id
            ? t.copyWith(
                endAt: () => null,
                pausedRemaining: () => remaining,
                notificationId: () => null,
              )
            : t,
    ];
  }

  Future<void> resumeTimer(String id) async {
    final index = state.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final timer = state[index];
    if (!timer.isPaused) return;

    final remaining = timer.pausedRemaining ?? timer.totalDuration;
    final notificationId = _notificationIdFor(timer.id);
    final endAt = DateTime.now().add(remaining);
    await scheduleOnce(
      id: notificationId,
      title: timer.label,
      body: 'Timer finished',
      at: endAt,
      soundId: timer.soundId,
      repeatSound: timer.repeatSound,
    );
    state = [
      for (final t in state)
        t.id == id
            ? t.copyWith(
                endAt: () => endAt,
                pausedRemaining: () => null,
                notificationId: () => notificationId,
              )
            : t,
    ];
  }

  /// Removes a timer — cancels its scheduled notification if it's still
  /// running (paused/finished timers have none scheduled).
  Future<void> removeTimer(String id) async {
    final timer = state.where((t) => t.id == id).firstOrNull;
    if (timer?.notificationId != null) {
      await cancelNotification(timer!.notificationId!);
    }
    state = state.where((t) => t.id != id).toList();
  }

  /// Restarts a finished timer for another full run of its original
  /// duration.
  Future<void> restartTimer(String id) async {
    final index = state.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final timer = state[index];
    await removeTimer(id);
    await addTimer(
      timer.totalDuration,
      label: timer.label,
      soundId: timer.soundId,
      repeatSound: timer.repeatSound,
    );
  }
}

final timerControllerProvider = StateNotifierProvider<TimerController, List<KitchenTimer>>(
  (ref) => TimerController(ref),
);
