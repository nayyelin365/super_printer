import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../label_printing/domain/label_component.dart';
import '../template_builder_controller.dart';

/// "+ Text / + Barcode / + Date/Time / + Divider" buttons that append a new
/// component (with sensible defaults) to the draft template and select it.
class ComponentPalette extends ConsumerWidget {
  const ComponentPalette({super.key});

  static const _entries = [
    (type: LabelComponentType.text, icon: Icons.text_fields, label: 'Text', vertical: false, filled: false),
    (type: LabelComponentType.barcode, icon: Icons.qr_code_2, label: 'Barcode', vertical: false, filled: false),
    (type: LabelComponentType.dateTime, icon: Icons.calendar_today, label: 'Date/Time', vertical: false, filled: false),
    (type: LabelComponentType.divider, icon: Icons.horizontal_rule, label: 'Divider', vertical: false, filled: false),
    (type: LabelComponentType.divider, icon: Icons.horizontal_rule, label: 'Vertical Divider', vertical: true, filled: false),
    (type: LabelComponentType.box, icon: Icons.crop_square, label: 'Outline Box', vertical: false, filled: false),
    (type: LabelComponentType.box, icon: Icons.square, label: 'Filled Box', vertical: false, filled: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(templateBuilderControllerProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in _entries)
          OutlinedButton.icon(
            onPressed: () => controller.addComponent(
              entry.type,
              vertical: entry.vertical,
              filled: entry.filled,
            ),
            icon: entry.vertical
                ? RotatedBox(quarterTurns: 1, child: Icon(entry.icon, size: 16))
                : Icon(entry.icon, size: 16),
            label: Text('+ ${entry.label}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.navyDark,
              side: const BorderSide(color: AppTheme.border),
            ),
          ),
      ],
    );
  }
}
