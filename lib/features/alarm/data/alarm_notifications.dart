import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/alarm_sound.dart';

/// Low-level wrapper around `flutter_local_notifications` - everything
/// alarm-specific (deciding when to fire, honoring repeat days) lives in
/// `NotificationAlarmScheduler`; this file only knows how to talk to the OS.
///
/// A plain top-level instance/functions rather than a class instantiated
/// through Riverpod: the notification-tap/action callback fires on a
/// background isolate when the app is fully killed (per
/// `flutter_local_notifications`'s contract, its handler must be a
/// `@pragma('vm:entry-point')` top-level or static function), which has no
/// `ProviderContainer` to read a provider from.
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

// v2: the original single channel used the default (notification) audio
// stream, which stays silent whenever the phone's notification volume/DND
// is off even if the alarm volume is up. Android also locks a channel's
// sound the moment it's first created, so supporting more than one sound
// means one channel per sound id, all under this prefix.
const _channelIdPrefix = 'alarms_v2_';
const _channelDescription = 'Alarm notifications';
const alarmCategoryId = 'alarm_actions';
const alarmActionDismiss = 'dismiss';
const alarmActionSnooze = 'snooze';
const snoozeMinutes = 5;

String _channelIdFor(String soundId) => '$_channelIdPrefix$soundId';

String _channelNameFor(String soundId) => 'Alarms (${alarmSoundById(soundId).label})';

/// The id alarms saved before the "Default" (system sound) option was
/// removed may still carry — kept only so those old alarms keep resolving
/// to the system sound (there's no `default.mp3` raw resource to play)
/// instead of silently failing. Not offered as a choice anywhere any more;
/// [defaultAlarmSoundId] is unrelated to this.
const _legacySystemSoundId = 'default';

/// The Android raw-resource sound for [soundId], or null for the system
/// default (Android plays its default alarm/notification sound when no
/// explicit sound is set on a channel with `playSound: true`).
AndroidNotificationSound? _androidSoundFor(String soundId) {
  return soundId == _legacySystemSoundId ? null : RawResourceAndroidNotificationSound(soundId);
}

/// Initializes the plugin, one Android notification channel per selectable
/// [AlarmSound], and the device's real timezone (required for
/// zonedSchedule to fire at the correct wall-clock time, including across
/// DST changes) - call once at app startup, before scheduling anything.
Future<void> initializeAlarmNotifications() async {
  tz_data.initializeTimeZones();
  try {
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
  } catch (_) {
    // Falls back to whatever `timezone` defaults to (UTC) - better than
    // crashing startup; alarms will just be off by the device's UTC
    // offset until this resolves (e.g. next app restart).
  }

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  final darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: false, // requested explicitly - see requestAlarmPermissions
    requestBadgePermission: false,
    requestSoundPermission: false,
    notificationCategories: [
      DarwinNotificationCategory(
        alarmCategoryId,
        actions: [
          DarwinNotificationAction.plain(
            alarmActionSnooze,
            'Snooze $snoozeMinutes min',
          ),
          DarwinNotificationAction.plain(
            alarmActionDismiss,
            'Dismiss',
            options: {DarwinNotificationActionOption.destructive},
          ),
        ],
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
  if (androidPlugin != null) {
    for (final sound in alarmSounds) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _channelIdFor(sound.id),
          _channelNameFor(sound.id),
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          sound: _androidSoundFor(sound.id),
          // Alarm (not notification) audio stream — plays regardless of
          // the phone's notification volume, silent mode, or DND, same as
          // a real alarm clock.
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ),
      );
    }
  }
}

/// Requests the notification permission (Android 13+, iOS) and, on
/// Android 12+, the exact-alarm permission, returning whether both ended
/// up granted. The caller (the alarm controller) surfaces a message rather
/// than silently failing to schedule when this comes back false.
Future<bool> requestAlarmPermissions() async {
  final androidPlugin =
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    final notificationsGranted = await androidPlugin.requestNotificationsPermission() ?? false;
    final exactAlarmsGranted = await androidPlugin.requestExactAlarmsPermission() ?? true;
    return notificationsGranted && exactAlarmsGranted;
  }

  final darwinPlugin =
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  if (darwinPlugin != null) {
    final granted = await darwinPlugin.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }

  return true;
}

Future<void> scheduleOnce({
  required int id,
  required String title,
  required String body,
  required DateTime at,
  String soundId = defaultAlarmSoundId,
  bool repeatSound = false,
}) {
  return _zonedSchedule(
    id: id,
    title: title,
    body: body,
    at: at,
    soundId: soundId,
    repeatSound: repeatSound,
    matchDateTimeComponents: null,
  );
}

/// Schedules a notification that recurs every week on [at]'s weekday/time,
/// handled natively by the OS (AlarmManager / UNCalendarNotificationTrigger),
/// so a repeating alarm never needs the app to re-schedule it after it fires.
Future<void> scheduleWeekly({
  required int id,
  required String title,
  required String body,
  required DateTime at,
  String soundId = defaultAlarmSoundId,
  bool repeatSound = false,
}) {
  return _zonedSchedule(
    id: id,
    title: title,
    body: body,
    at: at,
    soundId: soundId,
    repeatSound: repeatSound,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
  );
}

Future<void> _zonedSchedule({
  required int id,
  required String title,
  required String body,
  required DateTime at,
  required String soundId,
  required bool repeatSound,
  required DateTimeComponents? matchDateTimeComponents,
}) {
  // `flutter_local_notifications` doesn't implement scheduled notifications
  // on web at all (zonedSchedule() throws UnsupportedError there) — this
  // app is only ever really used on Android/iOS with a real printer, so on
  // web every alarm-scheduling call is a silent no-op rather than crashing
  // whatever feature tried to schedule one (e.g. the Sushi Rice SOP's
  // "Save & Print" batch creation, which would otherwise never finish
  // saving the batch just because the browser can't set a native alarm).
  if (kIsWeb) return Future.value();

  Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    // Carries title/body/soundId/repeatSound through to the
    // notification-response handler so Snooze can re-schedule with the
    // same text/sound/behavior - JSON-encoded rather than naively joined,
    // since title/body can contain spaces.
    payload: jsonEncode({
      'title': title,
      'body': body,
      'soundId': soundId,
      'repeatSound': repeatSound,
    }),
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    androidScheduleMode: mode,
    matchDateTimeComponents: matchDateTimeComponents,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channelIdFor(soundId),
        _channelNameFor(soundId),
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        playSound: true,
        sound: _androidSoundFor(soundId),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        // "Repeat sound": local notifications only ever play their sound
        // once when posted (there's no OS-level looping API exposed by
        // the plugin) - `ongoing` is the closest available substitute,
        // pinning the notification (non-swipeable) so it keeps re-alerting
        // via the heads-up/full-screen presentation until Dismiss/Snooze
        // is explicitly tapped, rather than just fading away on its own.
        ongoing: repeatSound,
        autoCancel: !repeatSound,
        actions: const [
          AndroidNotificationAction(alarmActionSnooze, 'Snooze $snoozeMinutes min'),
          AndroidNotificationAction(alarmActionDismiss, 'Dismiss', cancelNotification: true),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: alarmCategoryId,
        // iOS custom notification sounds must be bundled into the Xcode
        // project (Runner/Resources) as .aiff/.wav/.caf — see the iOS
        // limitation noted in the alarm feature summary. Falls back to
        // the system default sound if that file isn't actually bundled.
        sound: soundId == _legacySystemSoundId ? null : '$soundId.mp3',
      ),
    ),
  );

  // Exact alarms need the "Alarms & reminders" permission on Android 12+,
  // which some devices (and Android 14's default for fresh installs) leave
  // denied — the plugin then throws `exact_alarms_not_permitted` and the
  // alarm/timer would silently never exist. Fall back to an inexact
  // (still Doze-piercing, but possibly a little late) schedule instead of
  // failing.
  return schedule(AndroidScheduleMode.exactAllowWhileIdle).catchError((Object error) {
    if (error is PlatformException && error.code == 'exact_alarms_not_permitted') {
      return schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
    throw error;
  });
}

Future<void> cancelNotification(int id) => _plugin.cancel(id: id);

/// Snoozes by scheduling a new one-shot notification [snoozeMinutes] from
/// now, used by both the foreground and background action handlers below.
/// The title/body/sound come from the notification's JSON-encoded payload
/// (see _zonedSchedule), falling back to generic text/default sound if
/// that's ever missing. A fresh, time-derived id is used rather than the
/// original alarm's id, so a snoozed one-time alarm doesn't collide with,
/// or get silently replaced by, the next time that alarm's own id is
/// scheduled.
Future<void> _handleAction(NotificationResponse response) {
  if (response.actionId != alarmActionSnooze) {
    return Future.value();
  }

  var title = 'Alarm';
  var body = 'Alarm';
  var soundId = defaultAlarmSoundId;
  var repeatSound = false;
  final payload = response.payload;
  if (payload != null && payload.isNotEmpty) {
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      title = decoded['title'] as String? ?? title;
      body = decoded['body'] as String? ?? body;
      soundId = decoded['soundId'] as String? ?? soundId;
      repeatSound = decoded['repeatSound'] as bool? ?? repeatSound;
    } catch (_) {
      // Malformed/unexpected payload - fall back to the generic text
      // above rather than let a snooze tap silently do nothing.
    }
  }

  final snoozeId = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
  return scheduleOnce(
    id: snoozeId,
    title: title,
    body: body,
    at: DateTime.now().add(const Duration(minutes: snoozeMinutes)),
    soundId: soundId,
    repeatSound: repeatSound,
  );
}

/// Runs when a notification action/tap is received while the app process
/// is alive (foreground or background, but not killed).
void _onNotificationResponse(NotificationResponse response) => _handleAction(response);

/// The background-isolate counterpart of _onNotificationResponse - runs
/// with no access to the rest of the app (no Riverpod, no existing
/// isolate), which is exactly why the low-level snooze/cancel calls here
/// go straight through the plugin instead of via AlarmScheduler.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) => _handleAction(response);
