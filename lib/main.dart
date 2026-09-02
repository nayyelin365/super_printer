import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/alarm/data/alarm_notifications.dart';
import 'features/log_sheet/data/sushi_rice_notifications.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Sets up the notification plugin/channel/timezone before any alarm
  // could be scheduled — including the app-restart pass in
  // `AlarmController` that re-confirms every enabled alarm's schedule.
  await initializeAlarmNotifications();
  // Relies on the timezone setup `initializeAlarmNotifications` just did
  // (the `timezone` package's local location is process-global) — safe to
  // call after it, not before.
  await initializeSushiRiceNotifications();
  runApp(const ProviderScope(child: SuperPrinterApp()));
}
