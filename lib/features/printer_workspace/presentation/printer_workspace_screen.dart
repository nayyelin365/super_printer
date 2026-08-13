import 'package:flutter/material.dart';

import '../../label_printing/presentation/label_print_screen.dart';
import '../../printer_settings/presentation/printer_settings_screen.dart';
import '../../../shared/widgets/app_sidebar.dart';

/// The printer tool itself: sidebar navigation between the label print
/// screen and printer settings. Reached from [HomeScreen]'s "Print a
/// Label" call-to-action.
class PrinterWorkspaceScreen extends StatefulWidget {
  const PrinterWorkspaceScreen({super.key});

  @override
  State<PrinterWorkspaceScreen> createState() => _PrinterWorkspaceScreenState();
}

class _PrinterWorkspaceScreenState extends State<PrinterWorkspaceScreen> {
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
