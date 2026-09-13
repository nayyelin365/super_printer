import '../../alarm/domain/alarm_sound.dart';

/// A running/paused/finished countdown timer, styled after a phone Clock
/// app's Timers tab — but backed by a real scheduled notification (see
/// `TimerController.addTimer`) on the *same* notification channels the
/// Alarms feature already created, so ending a timer sounds/vibrates
/// exactly like an alarm going off, per this app's "route kitchen-timer-
/// style alerts through the existing alarm notification plumbing instead
/// of a bespoke channel" convention — this doesn't go through
/// `AlarmController.addAlarm` itself because `Alarm` only has minute
/// precision (no seconds): rounding a timer's fire time to the alarm's
/// hour/minute can land it in the past-this-minute and get bumped a whole
/// day, which is wrong for anything under a minute. Scheduling the
/// notification directly (`scheduleOnce`/`cancelNotification` from
/// `alarm_notifications.dart`) keeps second-level accuracy while reusing
/// the same channels.
///
/// Kept in memory only (no storage) — the scheduled notification is what
/// survives the app being killed and actually fires the sound; losing the
/// live countdown list on an app restart is an acceptable trade-off for not
/// needing a second persistence layer.
class KitchenTimer {
  const KitchenTimer({
    required this.id,
    required this.label,
    required this.totalDuration,
    this.soundId = defaultAlarmSoundId,
    this.repeatSound = false,
    this.endAt,
    this.pausedRemaining,
    this.notificationId,
    this.isFinished = false,
  });

  /// Stable identity for list operations — a uuid, generated once.
  final String id;

  final String label;
  final Duration totalDuration;

  /// Which `AlarmSound` plays when this timer ends — an id from
  /// `alarmSounds`, same picker as the Alarms feature.
  final String soundId;

  /// Whether the end-of-timer sound should keep re-alerting until
  /// dismissed, instead of sounding once and going quiet — same behavior
  /// as `Alarm.repeatSound`, passed straight through to `scheduleOnce`.
  final bool repeatSound;

  /// The moment this timer is due to finish, while running. Null while
  /// paused or finished.
  final DateTime? endAt;

  /// Remaining time as of the moment this timer was paused. Null while
  /// running or finished.
  final Duration? pausedRemaining;

  /// The OS notification id currently scheduled to fire the end-of-timer
  /// sound — present only while running (see `TimerController`).
  final int? notificationId;

  final bool isFinished;

  bool get isRunning => endAt != null;
  bool get isPaused => !isRunning && !isFinished;

  /// Time left right now — ticks down live while running, frozen while
  /// paused, zero once finished.
  Duration get remaining {
    if (isFinished) return Duration.zero;
    if (endAt != null) {
      final left = endAt!.difference(DateTime.now());
      return left.isNegative ? Duration.zero : left;
    }
    return pausedRemaining ?? totalDuration;
  }

  String get remainingLabel {
    final total = remaining;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  KitchenTimer copyWith({
    DateTime? Function()? endAt,
    Duration? Function()? pausedRemaining,
    int? Function()? notificationId,
    bool? isFinished,
  }) {
    return KitchenTimer(
      id: id,
      label: label,
      totalDuration: totalDuration,
      soundId: soundId,
      repeatSound: repeatSound,
      endAt: endAt != null ? endAt() : this.endAt,
      pausedRemaining: pausedRemaining != null ? pausedRemaining() : this.pausedRemaining,
      notificationId: notificationId != null ? notificationId() : this.notificationId,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}
