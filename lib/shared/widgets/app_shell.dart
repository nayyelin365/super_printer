import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_sidebar.dart';

/// The go_router `ShellRoute` builder for the whole app — wraps every
/// routed page in the persistent left [AppSidebar], so the sidebar stays
/// mounted (and its selection reflects the current route) while the page
/// underneath changes.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  AppSection get _selected {
    if (location.startsWith('/settings')) return AppSection.settings;
    if (location.startsWith('/alarms')) return AppSection.alarms;
    return AppSection.print;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selected: _selected,
            onSelect: (section) => context.go(switch (section) {
              // The Print tab's job is to start the print flow, which
              // begins at template choice, not the print page itself.
              AppSection.print => '/templates',
              AppSection.alarms => '/alarms',
              AppSection.settings => '/settings',
            }),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
