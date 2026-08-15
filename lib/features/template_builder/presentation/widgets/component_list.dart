import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../label_printing/domain/label_component.dart';
import '../template_builder_controller.dart';

/// The draft template's components as a selectable, deletable list — the
/// builder's "layers panel". Tap to select (and edit via
/// [ComponentPropertyEditor]); the trash icon removes it.
class ComponentList extends ConsumerWidget {
  const ComponentList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(templateBuilderControllerProvider);
    final controller = ref.read(templateBuilderControllerProvider.notifier);
    final components = state.template.components;

    if (components.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No components yet. Add one above.',
          style: TextStyle(fontSize: 12, color: Colors.black45),
        ),
      );
    }

    return Column(
      children: [
        for (final component in components)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: state.selectedComponentId == component.id
                    ? AppTheme.amber
                    : AppTheme.border,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: state.selectedComponentId == component.id
                  ? AppTheme.amber.withValues(alpha: 0.15)
                  : Colors.white,
              child: ListTile(
                dense: true,
                leading: Icon(_iconFor(component.type), size: 18),
                title: Text(
                  _labelFor(component),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Remove component',
                  onPressed: () => controller.removeComponent(component.id),
                ),
                onTap: () => controller.selectComponent(component.id),
              ),
            ),
          ),
      ],
    );
  }

  IconData _iconFor(LabelComponentType type) => switch (type) {
        LabelComponentType.text => Icons.text_fields,
        LabelComponentType.barcode => Icons.qr_code_2,
        LabelComponentType.dateTime => Icons.calendar_today,
        LabelComponentType.divider => Icons.horizontal_rule,
        LabelComponentType.image => Icons.image_outlined,
      };

  String _labelFor(LabelComponent component) {
    if (component.type == LabelComponentType.divider) return 'Divider';
    if (component.fieldKey != null) return LabelFieldKey.label(component.fieldKey!);
    return component.value?.isNotEmpty == true ? component.value! : 'Untitled';
  }
}
