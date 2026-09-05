/// A selectable alarm sound. [id] is persisted on the [Alarm] and doubles
/// as the Android raw-resource name (see `alarm_notifications.dart`) —
/// Android locks a notification channel's sound the moment the channel is
/// first created, so each sound gets its own channel, one per [id].
class AlarmSound {
  const AlarmSound({required this.id, required this.label, this.assetPath});

  /// Stable identity, persisted on the alarm — must match both a raw
  /// resource in `android/app/src/main/res/raw/<id>.mp3` and a bundled
  /// Flutter asset at [assetPath] (used for in-app preview).
  final String id;

  final String label;

  /// Flutter asset path used only for in-app preview playback — the
  /// actual scheduled notification plays the Android raw resource, not
  /// this asset (Android can't play a Flutter asset directly as a
  /// notification sound).
  final String? assetPath;
}

/// The sound every new alarm starts pre-selected with (and the fallback
/// for a legacy/unrecognized id) — Alarm 1. There's no "Default" (system
/// sound) option any more; every alarm has one of these three real sounds.
const defaultAlarmSoundId = 'alarm1';

const alarmSounds = [
  AlarmSound(id: 'alarm1', label: 'Alarm 1', assetPath: 'assets/alarm/alarm2.mp3'),
  AlarmSound(id: 'alarm2', label: 'Alarm 2', assetPath: 'assets/alarm/alarm1.mp3'),
  AlarmSound(id: 'alarm3', label: 'Alarm 3', assetPath: 'assets/alarm/alarm3.mp3'),
];

AlarmSound alarmSoundById(String id) =>
    alarmSounds.firstWhere((s) => s.id == id, orElse: () => alarmSounds.first);
