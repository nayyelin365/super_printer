import 'alarm_sound.dart';

/// A single alarm, styled after a phone Clock app: a time of day, an
/// optional set of repeat days, and enable/disable — see `AlarmScheduler`
/// for how this turns into OS-level scheduled notifications.
class Alarm {
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    this.note = '',
    this.enabled = true,
    this.repeatDays = const <int>{},
    this.oneTimeDate,
    this.soundId = defaultAlarmSoundId,
    this.repeatSound = false,
  });

  /// Stable identity for storage, list operations, and deriving the OS
  /// notification id (see `stableAlarmBaseId`) — a uuid, generated once at
  /// creation and never reused.
  final String id;

  final int hour;
  final int minute;
  final String title;
  final String note;
  final bool enabled;

  /// 1 (Monday) .. 7 (Sunday), matching [DateTime.weekday]. Empty means a
  /// one-time alarm.
  final Set<int> repeatDays;

  /// The calendar date (time-of-day components ignored) a one-time alarm
  /// is scheduled for — always non-null when [repeatDays] is empty, and
  /// always null otherwise. Recomputed by `AlarmController` to "the next
  /// upcoming [hour]:[minute]" every time a one-time alarm is created,
  /// edited, or re-enabled — never rolled forward automatically once set,
  /// so a fired one-time alarm can be told apart from one still pending
  /// (see `AlarmController.restore`).
  final DateTime? oneTimeDate;

  /// Which [AlarmSound] plays when this alarm fires — an id from
  /// `alarmSounds`. Android locks a notification channel's sound at
  /// creation, so the scheduler picks the channel matching this id (see
  /// `alarm_notifications.dart`).
  final String soundId;

  /// Whether the alarm sound should keep playing/re-alerting until the
  /// seller explicitly dismisses or snoozes it, instead of sounding once
  /// and going quiet. See `alarm_notifications.dart` for how this maps to
  /// `AndroidNotificationDetails` — and its documented platform limits.
  final bool repeatSound;

  bool get isOneTime => repeatDays.isEmpty;

  /// The exact moment this alarm is scheduled to fire next — for a
  /// one-time alarm that's always [oneTimeDate] + time (it never rolls
  /// forward); for a repeating alarm it's the next matching weekday
  /// from [now].
  DateTime nextOccurrence({DateTime? now}) {
    if (isOneTime) {
      final date = oneTimeDate!;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    final reference = now ?? DateTime.now();
    for (var offset = 0; offset < 8; offset++) {
      final date = reference.add(Duration(days: offset));
      final candidate = DateTime(date.year, date.month, date.day, hour, minute);
      if (repeatDays.contains(candidate.weekday) && candidate.isAfter(reference)) {
        return candidate;
      }
    }
    throw StateError('No matching repeat day found for alarm $id');
  }

  /// The next occurrence of a specific [weekday] (1=Mon..7=Sun) — used by
  /// the scheduler to give each repeat day its own OS-native weekly
  /// recurrence.
  DateTime nextOccurrenceOfWeekday(int weekday, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    for (var offset = 0; offset < 8; offset++) {
      final date = reference.add(Duration(days: offset));
      final candidate = DateTime(date.year, date.month, date.day, hour, minute);
      if (candidate.weekday == weekday && candidate.isAfter(reference)) {
        return candidate;
      }
    }
    throw StateError('Unreachable: every weekday occurs within 8 days');
  }

  String get timeLabel {
    final period = hour < 12 ? 'AM' : 'PM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  static const _dayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

  /// "Once", "Every day", "Weekdays", "Weekends", or a "Mon, Wed, Fri"
  /// list — whichever reads most naturally for the current selection.
  String get repeatLabel {
    if (repeatDays.isEmpty) return 'Once';
    if (repeatDays.length == 7) return 'Every day';
    if (repeatDays.length == 5 && repeatDays.containsAll(const {1, 2, 3, 4, 5})) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 && repeatDays.containsAll(const {6, 7})) return 'Weekends';
    final sorted = repeatDays.toList()..sort();
    return sorted.map((d) => _dayLabels[d]).join(', ');
  }

  Alarm copyWith({
    int? hour,
    int? minute,
    String? title,
    String? note,
    bool? enabled,
    Set<int>? repeatDays,
    DateTime? Function()? oneTimeDate,
    String? soundId,
    bool? repeatSound,
  }) {
    return Alarm(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      title: title ?? this.title,
      note: note ?? this.note,
      enabled: enabled ?? this.enabled,
      repeatDays: repeatDays ?? this.repeatDays,
      oneTimeDate: oneTimeDate != null ? oneTimeDate() : this.oneTimeDate,
      soundId: soundId ?? this.soundId,
      repeatSound: repeatSound ?? this.repeatSound,
    );
  }

  factory Alarm.fromJson(Map<String, dynamic> json) {
    final oneTimeDateStr = json['oneTimeDate'] as String?;
    return Alarm(
      id: json['id'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      title: json['title'] as String,
      note: json['note'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      repeatDays: (json['repeatDays'] as List<dynamic>? ?? []).map((d) => d as int).toSet(),
      oneTimeDate: oneTimeDateStr != null ? DateTime.parse(oneTimeDateStr) : null,
      soundId: json['soundId'] as String? ?? defaultAlarmSoundId,
      repeatSound: json['repeatSound'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'title': title,
      'note': note,
      'enabled': enabled,
      'repeatDays': (repeatDays.toList()..sort()),
      if (oneTimeDate != null) 'oneTimeDate': oneTimeDate!.toIso8601String(),
      'soundId': soundId,
      'repeatSound': repeatSound,
    };
  }
}

/// A deterministic (stable across app restarts, Dart versions, and
/// platforms — unlike [Object.hashCode]) hash of [id], used to derive the
/// OS notification ids the scheduler schedules/cancels for this alarm.
/// Masked to 24 bits so `* 10 + subId` (subId up to 9) never overflows a
/// signed 32-bit int, which is what Android notification ids are.
int stableAlarmBaseId(String id) {
  var hash = 0x811C9DC5; // FNV-1a 32-bit offset basis
  for (final unit in id.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime, wrapped to 32 bits
  }
  return hash & 0x00FFFFFF;
}
