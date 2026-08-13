import 'package:flutter/material.dart';

import 'features/label_printing/presentation/label_print_screen.dart';
import 'features/printer_settings/presentation/printer_settings_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/app_sidebar.dart';

class SuperPrinterApp extends StatelessWidget {
  const SuperPrinterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlavorHub Label Print',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _AppShell(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  AppSection _section = AppSection.print;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selected: _section,
            onSelect: (s) => setState(() => _section = s),
          ),
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(child: LabelPrintScreen()),
                if (_section == AppSection.settings)
                  const Positioned.fill(child: PrinterSettingsScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
