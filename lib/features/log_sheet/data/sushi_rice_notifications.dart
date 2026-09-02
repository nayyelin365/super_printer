import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../firebase_options.dart';
import '../domain/sushi_rice_batch.dart';

/// Low-level `flutter_local_notifications` wrapper for the Sushi Rice SOP —
/// a separate plugin instance/channel from `alarm_notifications.dart`, but
/// the two coexist fine since each `FlutterLocalNotificationsPlugin()`
/// instance is just a thin wrapper over the same OS notification manager.
///
/// Multiple batches run concurrently, so every notification id is derived
/// from the batch's Firestore document id plus a per-purpose sub-id.
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

const _channelId = 'sushi_rice_sop';
const _channelName = 'Sushi Rice SOP';
const _channelDescription = 'Sushi Rice procedure step and compliance alerts';
const _categoryId = 'sushi_rice_actions';
const _actionAcknowledge = 'sushi_rice_acknowledge';

int _stableBatchBaseId(String batchId) {
  var hash = 0x811C9DC5; // FNV-1a 32-bit offset basis
  for (final unit in batchId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime, wrapped to 32 bits
  }
  // Leaves room for `* 1000 + subId` (below) to stay within a 32-bit
  // notification id.
  return hash & 0x0007FFFF;
}

// Sub-id ranges within one batch's `* 1000` block:
//   0-4:     stage "Time's Up!" alerts (SushiRiceStage.index)
//   100-104: TPHC hour-mark alerts (hour index 0..4)
//   200+:    TPHC reminders (200 + hourIndex*20 + n)
int _stageAlertId(String batchId, SushiRiceStage stage) =>
    _stableBatchBaseId(batchId) * 1000 + stage.index;

int _tphcAlertId(String batchId, int hourIndex) => _stableBatchBaseId(batchId) * 1000 + 100 + hourIndex;

const _remindersPerHour = 12; // every 5 min for the hour until the next mark

int _tphcReminderId(String batchId, int hourIndex, int n) =>
    _stableBatchBaseId(batchId) * 1000 + 200 + hourIndex * 20 + n;

Future<void> initializeSushiRiceNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  final darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    notificationCategories: [
      DarwinNotificationCategory(
        _categoryId,
        actions: [DarwinNotificationAction.plain(_actionAcknowledge, 'Acknowledge')],
      ),
    ],
  );

  await _plugin.initialize(
    settings: InitializationSettings(android: androidSettings, iOS: darwinSettings),
    onDidReceiveNotificationResponse: _onNotificationResponse,
    onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
  );

  final androidPlugin =
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      // `playSound: true` with no explicit `sound:` uses the device's
      // default alarm sound — audible even with the phone's ringer
      // silent/DND, thanks to `audioAttributesUsage: alarm` below.
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
    ),
  );
}

NotificationDetails _details({bool ongoing = false, List<AndroidNotificationAction>? actions}) {
  return NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      ongoing: ongoing,
      autoCancel: !ongoing,
      actions: actions,
    ),
    iOS: DarwinNotificationDetails(
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: actions != null ? _categoryId : null,
    ),
  );
}

/// Schedules the one-shot "Time's Up!" alert for [batchId]'s [stage] at
/// [at] — fires as a real OS notification, with sound, even if the app is
/// backgrounded or fully closed.
Future<void> scheduleStageDoneAlert({
  required String batchId,
  required SushiRiceStage stage,
  required String title,
  required String body,
  required DateTime at,
}) {
  return _plugin.zonedSchedule(
    id: _stageAlertId(batchId, stage),
    title: title,
    body: body,
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    notificationDetails: _details(),
  );
}

Future<void> cancelStageDoneAlert(String batchId, SushiRiceStage stage) =>
    _plugin.cancel(id: _stageAlertId(batchId, stage));

Future<void> cancelAllStageAlerts(String batchId) => Future.wait([
  for (final stage in SushiRiceStage.values) cancelStageDoneAlert(batchId, stage),
]);

/// Schedules all five TPHC hour-mark alerts (see [sushiRiceTphcAlertHours])
/// relative to [readyToUseStartedAt] for [batchId], each followed by real,
/// independently-timed reminders every [sushiRiceTphcReminderInterval] for
/// the hour until the next mark — all cancelled in bulk the moment that
/// hour is acknowledged (see [_acknowledgeHour]) or the batch is finished/
/// discarded ([cancelTphcAlerts]).
Future<void> scheduleTphcAlerts(String batchId, DateTime readyToUseStartedAt) async {
  for (var i = 0; i < sushiRiceTphcAlertHours.length; i++) {
    final hour = sushiRiceTphcAlertHours[i];
    final hourMarkAt = readyToUseStartedAt.add(Duration(hours: hour));
    final payload = jsonEncode({'batchId': batchId, 'hourIndex': i});
    final actions = [AndroidNotificationAction(_actionAcknowledge, 'Acknowledge', cancelNotification: true)];

    await _plugin.zonedSchedule(
      id: _tphcAlertId(batchId, i),
      title: 'Sushi Rice — TPHC Check ($hour hr)',
      body: 'Acknowledge required — test pH or discard if past 24 hours.',
      scheduledDate: tz.TZDateTime.from(hourMarkAt, tz.local),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      notificationDetails: _details(ongoing: true, actions: actions),
    );

    for (var n = 1; n <= _remindersPerHour; n++) {
      final reminderAt = hourMarkAt.add(sushiRiceTphcReminderInterval * n);
      await _plugin.zonedSchedule(
        id: _tphcReminderId(batchId, i, n),
        title: 'Sushi Rice — TPHC Check ($hour hr)',
        body: 'Still waiting on acknowledgement.',
        scheduledDate: tz.TZDateTime.from(reminderAt, tz.local),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
        notificationDetails: _details(ongoing: true, actions: actions),
      );
    }
  }
}

/// Cancels every scheduled TPHC alert/reminder for [batchId] — called on
/// Finish Batch or Discard Batch.
Future<void> cancelTphcAlerts(String batchId) async {
  for (var i = 0; i < sushiRiceTphcAlertHours.length; i++) {
    await _cancelHourAlerts(batchId, i);
  }
}

Future<void> _cancelHourAlerts(String batchId, int hourIndex) async {
  await _plugin.cancel(id: _tphcAlertId(batchId, hourIndex));
  for (var n = 1; n <= _remindersPerHour; n++) {
    await _plugin.cancel(id: _tphcReminderId(batchId, hourIndex, n));
  }
}

/// Best-effort — re-initializes Firebase if this callback is running on a
/// fresh background isolate (the OS can invoke a notification action
/// handler without ever running `main()`), so the Firestore write below
/// doesn't throw. If this fails, the notification is still cancelled
/// (the part that actually matters for stopping the nagging); only the
/// foreground dashboard's "needs acknowledgement" banner might not clear
/// until the app is reopened.
Future<void> _ensureFirebaseReady() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Already initializing elsewhere, or genuinely unavailable — the
    // Firestore call below will just fail and be caught there too.
  }
}

Future<void> _acknowledgeHour(String batchId, int hourIndex) async {
  await _cancelHourAlerts(batchId, hourIndex);

  try {
    await _ensureFirebaseReady();
    final hour = sushiRiceTphcAlertHours[hourIndex];
    await FirebaseFirestore.instance
        .collection('sushi_rice_batches')
        .doc(batchId)
        .update({'lastAcknowledgedHour': hour});
  } catch (_) {
    // Best-effort — see the doc comment on `_ensureFirebaseReady`.
  }
}

Future<void> _onAction(NotificationResponse response) async {
  if (response.actionId != _actionAcknowledge) return;
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  try {
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    final batchId = decoded['batchId'] as String?;
    final hourIndex = decoded['hourIndex'] as int?;
    if (batchId != null && hourIndex != null) await _acknowledgeHour(batchId, hourIndex);
  } catch (_) {
    // Malformed/unexpected payload — nothing sensible to acknowledge.
  }
}

void _onNotificationResponse(NotificationResponse response) => _onAction(response);

@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) => _onAction(response);
