import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the initials/name last used when saving a log entry, so the
/// field can be pre-filled instead of retyped every time — the app has no
/// login/employee-identity system to pull this from instead (see the log
/// sheet feature summary).
class LogPreferences {
  static const _lastInitialsKey = 'log_last_initials';

  Future<String?> loadLastInitials() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastInitialsKey);
  }

  Future<void> saveLastInitials(String initials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastInitialsKey, initials);
  }
}
