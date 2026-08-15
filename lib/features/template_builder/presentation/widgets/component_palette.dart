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
    (LabelComponentType.text, Icons.text_fields, 'Text'),
    (LabelComponentType.barcode, Icons.qr_code_2, 'Barcode'),
    (LabelComponentType.dateTime, Icons.calendar_today, 'Date/Time'),
    (LabelComponentType.divider, Icons.horizontal_rule, 'Divider'),
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
            onPressed: () => controller.addComponent(entry.$1),
            icon: Icon(entry.$2, size: 16),
            label: Text('+ ${entry.$3}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.navyDark,
              side: const BorderSide(color: AppTheme.border),
            ),
          ),
      ],
    );
  }
}
