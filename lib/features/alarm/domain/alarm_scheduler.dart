import 'alarm.dart';

/// OS-level alarm scheduling, kept behind an interface so the rest of the
/// app (the controller, the UI) never talks to `flutter_local_notifications`
/// directly — see `NotificationAlarmScheduler` for the concrete
/// implementation.
abstract class AlarmScheduler {
  /// Schedules [alarm]'s next occurrence(s) — a single one-shot
  /// notification for a one-time alarm, or one OS-native weekly-recurring
  /// notification per selected repeat day. Implementations must cancel any
  /// previously scheduled notifications for this alarm first, so calling
  /// this twice never leaves duplicates. A no-op if `alarm.enabled` is
  /// false.
  Future<void> schedule(Alarm alarm);

  /// Cancels every notification scheduled for the alarm with this id.
  Future<void> cancel(String alarmId);

  /// Cancels then re-schedules — used when an alarm is edited.
  Future<void> reschedule(Alarm alarm);
}
