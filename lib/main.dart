import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/alarm/data/alarm_notifications.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Sets up the notification plugin/channel/timezone before any alarm
  // could be scheduled — including the app-restart pass in
  // `AlarmController` that re-confirms every enabled alarm's schedule.
  // The Sushi Rice SOP's buzzers/TPHC alerts are real Alarms scheduled
  // through this same system (see `SushiRiceBatchController`), not a
  // separate notification channel — no second init call needed.
  await initializeAlarmNotifications();
  runApp(const ProviderScope(child: SuperPrinterApp()));
}
