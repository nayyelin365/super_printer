import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../label_printing/presentation/label_print_screen.dart';
import '../../printer_settings/presentation/printer_settings_screen.dart';
import '../../../shared/widgets/app_sidebar.dart';
import 'app_section_controller.dart';

/// The printer tool itself: sidebar navigation between the label print
/// screen and printer settings. Reached from [HomeScreen]'s "Print a
/// Label" call-to-action.
class PrinterWorkspaceScreen extends ConsumerWidget {
  const PrinterWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(appSectionProvider);

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selected: section,
            onSelect: (s) => ref.read(appSectionProvider.notifier).state = s,
          ),
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(child: LabelPrintScreen()),
                if (section == AppSection.settings)
                  const Positioned.fill(child: PrinterSettingsScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
