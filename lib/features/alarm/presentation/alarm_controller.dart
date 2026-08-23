import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/alarm_notifications.dart';
import '../data/alarm_storage.dart';
import '../data/notification_alarm_scheduler.dart';
import '../domain/alarm.dart';
import '../domain/alarm_scheduler.dart';
import '../domain/alarm_sound.dart';

const _uuid = Uuid();

/// Alarms, backed by [AlarmStorage] and driven through [AlarmScheduler] -
/// every mutation that changes what should fire (create, edit, enable,
/// disable, delete) is persisted immediately and reflected in the OS
/// schedule immediately, so the two never drift apart.
class AlarmController extends StateNotifier<List<Alarm>> {
  AlarmController(this._storage, this._scheduler) : super(const []) {
    _restore();
  }

  final AlarmStorage _storage;
  final AlarmScheduler _scheduler;

  Future<void> _restore() async {
    var alarms = await _storage.loadAll();

    // One-time alarms have no "did it fire" callback from the OS when the
    // app was killed at the time - the only place we can detect that is
    // here, by noticing the scheduled moment has already passed. This is
    // also what actually implements "trigger once, then auto-disable".
    final now = DateTime.now();
    bool hasFired(Alarm a) => a.enabled && a.isOneTime && a.nextOccurrence().isBefore(now);
    if (alarms.any(hasFired)) {
      alarms = [
        for (final alarm in alarms) hasFired(alarm) ? alarm.copyWith(enabled: false) : alarm,
      ];
      await _storage.saveAll(alarms);
    }
    state = alarms;

    // Make sure every enabled alarm actually has something scheduled -
    // covers first install, app data restore, and Android reboots on OS
    // versions where the plugin's own boot receiver hasn't run yet.
    // `schedule` cancels-then-reschedules, so this never duplicates.
    for (final alarm in state.where((a) => a.enabled)) {
      await _scheduler.schedule(alarm);
    }
  }

  /// Requests notification (and, on Android 12+, exact-alarm) permission.
  /// Callers should check this before relying on an alarm actually firing
  /// and surface a message if it comes back false rather than silently
  /// scheduling something that will never show up.
  Future<bool> ensurePermissions() => requestAlarmPermissions();

  /// Computes the [Alarm.oneTimeDate] for a one-time alarm: the next
  /// upcoming occurrence of [hour]:[minute] from now (today if that time
  /// hasn't passed yet, otherwise tomorrow). Recomputed on every save so a
  /// one-time alarm always represents "the next time this fires", never a
  /// stale date left over from a previous edit.
  DateTime _oneTimeDateFor(int hour, int minute) {
    final now = DateTime.now();
    var date = DateTime(now.year, now.month, now.day);
    final candidate = DateTime(date.year, date.month, date.day, hour, minute);
    if (!candidate.isAfter(now)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  Future<Alarm> addAlarm({
    required int hour,
    required int minute,
    required String title,
    String note = '',
    bool enabled = true,
    Set<int> repeatDays = const <int>{},
    String soundId = defaultAlarmSoundId,
    bool repeatSound = false,
  }) async {
    final alarm = Alarm(
      id: _uuid.v4(),
      hour: hour,
      minute: minute,
      title: title,
      note: note,
      enabled: enabled,
      repeatDays: repeatDays,
      oneTimeDate: repeatDays.isEmpty ? _oneTimeDateFor(hour, minute) : null,
      soundId: soundId,
      repeatSound: repeatSound,
    );
    state = [...state, alarm];
    await _storage.saveAll(state);
    if (enabled) await _scheduler.schedule(alarm);
    return alarm;
  }

  Future<void> updateAlarm(
    String id, {
    required int hour,
    required int minute,
    required String title,
    String note = '',
    required bool enabled,
    Set<int> repeatDays = const <int>{},
    String soundId = defaultAlarmSoundId,
    bool repeatSound = false,
  }) async {
    final index = state.indexWhere((a) => a.id == id);
    if (index == -1) return;

    final updated = state[index].copyWith(
      hour: hour,
      minute: minute,
      title: title,
      note: note,
      enabled: enabled,
      repeatDays: repeatDays,
      oneTimeDate: () => repeatDays.isEmpty ? _oneTimeDateFor(hour, minute) : null,
      soundId: soundId,
      repeatSound: repeatSound,
    );
    state = [for (final a in state) a.id == id ? updated : a];
    await _storage.saveAll(state);
    await _scheduler.reschedule(updated);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final index = state.indexWhere((a) => a.id == id);
    if (index == -1) return;

    var updated = state[index].copyWith(enabled: enabled);
    // Re-enabling a one-time alarm needs a fresh oneTimeDate - the old one
    // may already be in the past (that's exactly why it got disabled).
    if (enabled && updated.isOneTime) {
      updated = updated.copyWith(
        oneTimeDate: () => _oneTimeDateFor(updated.hour, updated.minute),
      );
    }
    state = [for (final a in state) a.id == id ? updated : a];
    await _storage.saveAll(state);
    if (enabled) {
      await _scheduler.schedule(updated);
    } else {
      await _scheduler.cancel(id);
    }
  }

  Future<void> deleteAlarm(String id) async {
    state = state.where((a) => a.id != id).toList();
    await _storage.saveAll(state);
    await _scheduler.cancel(id);
  }
}

final alarmStorageProvider = Provider<AlarmStorage>((ref) => AlarmStorage());

final alarmSchedulerProvider = Provider<AlarmScheduler>(
  (ref) => const NotificationAlarmScheduler(),
);

final alarmControllerProvider = StateNotifierProvider<AlarmController, List<Alarm>>(
  (ref) => AlarmController(ref.watch(alarmStorageProvider), ref.watch(alarmSchedulerProvider)),
);

/// The alarm currently open in the editor - null means "creating a new
/// alarm" (mirrors `editingTemplateProvider`'s pattern).
final editingAlarmProvider = StateProvider<Alarm?>((ref) => null);
