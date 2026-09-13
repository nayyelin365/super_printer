import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../timer/presentation/timer_list_screen.dart';
import 'alarm_list_screen.dart';

/// Routed at `/alarms` — hosts the "Alarms" and "Timers" tabs behind a
/// bottom navigation bar (like a phone Clock app's tab bar), an
/// `IndexedStack` so switching tabs doesn't lose either one's state (in
/// particular, a running timer keeps ticking while the Alarms tab is
/// shown).
class AlarmHomeScreen extends StatefulWidget {
  const AlarmHomeScreen({super.key});

  @override
  State<AlarmHomeScreen> createState() => _AlarmHomeScreenState();
}

class _AlarmHomeScreenState extends State<AlarmHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: IndexedStack(
        index: _tabIndex,
        sizing: StackFit.expand,
        children: const [
          AlarmListScreen(),
          TimerListScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Alarms',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Timers',
          ),
        ],
      ),
    );
  }
}
