import '../domain/alarm.dart';
import '../domain/alarm_scheduler.dart';
import 'alarm_notifications.dart';

/// [AlarmScheduler] backed by `flutter_local_notifications`.
///
/// One-time alarms get a single scheduled notification. Recurring alarms
/// get one notification per selected repeat day, each using the OS's own
/// weekly-recurrence support (`DateTimeComponents.dayOfWeekAndTime`) - so
/// e.g. Mon + Wed + Fri keeps firing every week indefinitely without the
/// app ever needing to re-schedule it.
class NotificationAlarmScheduler implements AlarmScheduler {
  const NotificationAlarmScheduler();

  /// Sub-id for the one-time schedule; repeat days use their own
  /// weekday number (1-7), so this just needs to not collide with those.
  static const _oneTimeSubId = 9;

  int _notificationId(String alarmId, int subId) => stableAlarmBaseId(alarmId) * 10 + subId;

  @override
  Future<void> schedule(Alarm alarm) async {
    // Cancel first, unconditionally - makes this idempotent (safe to call
    // on every app start, edit, or enable) and guarantees no duplicate
    // notifications ever accumulate for the same alarm.
    await cancel(alarm.id);
    if (!alarm.enabled) return;

    final body = alarm.note.trim().isEmpty ? 'Alarm' : alarm.note.trim();

    if (alarm.isOneTime) {
      await scheduleOnce(
        id: _notificationId(alarm.id, _oneTimeSubId),
        title: alarm.title,
        body: body,
        at: alarm.nextOccurrence(),
        soundId: alarm.soundId,
        repeatSound: alarm.repeatSound,
      );
    } else {
      for (final weekday in alarm.repeatDays) {
        await scheduleWeekly(
          id: _notificationId(alarm.id, weekday),
          title: alarm.title,
          body: body,
          at: alarm.nextOccurrenceOfWeekday(weekday),
          soundId: alarm.soundId,
          repeatSound: alarm.repeatSound,
        );
      }
    }
  }

  @override
  Future<void> cancel(String alarmId) async {
    final base = stableAlarmBaseId(alarmId);
    // Sub-ids 1-7 (weekdays) + 9 (one-time) - see _notificationId.
    for (final subId in [1, 2, 3, 4, 5, 6, 7, _oneTimeSubId]) {
      await cancelNotification(base * 10 + subId);
    }
  }

  @override
  Future<void> reschedule(Alarm alarm) => schedule(alarm);
}
