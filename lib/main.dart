import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/alarm/data/alarm_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sets up the notification plugin/channel/timezone before any alarm
  // could be scheduled — including the app-restart pass in
  // `AlarmController` that re-confirms every enabled alarm's schedule.
  await initializeAlarmNotifications();
  runApp(const ProviderScope(child: SuperPrinterApp()));
}
