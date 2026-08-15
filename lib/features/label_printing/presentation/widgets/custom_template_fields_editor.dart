import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/custom_label_data.dart';
import '../../domain/label_component.dart';
import '../label_print_controller.dart';

/// Editable fields for a custom (user-created) template, built dynamically
/// from its component list — one input per field-bound component. Static
/// text and dividers aren't editable here since they're fixed by the
/// template design; quantity has its own stepper in [PrintDetailsPanel], so
/// it's skipped too.
class CustomTemplateFieldsEditor extends ConsumerWidget {
  const CustomTemplateFieldsEditor({super.key});

  static final _dateTimeFormat = DateFormat('MM/dd/yyyy hh:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelPrintControllerProvider);
    final controller = ref.read(labelPrintControllerProvider.notifier);
    final data = state.labelData as CustomLabelData;

    final editableComponents = data.template.components.where((c) {
      final key = c.fieldKey;
      if (key == null) return false;
      if (key == LabelFieldKey.quantity) return false;
      return true;
    }).toList();

    if (editableComponents.isEmpty) {
      return const Text(
        'This template has no editable fields.',
        style: TextStyle(fontSize: 12, color: Colors.black45),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final component in editableComponents) ...[
          _fieldFor(context, state, controller, data, component),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _fieldFor(
    BuildContext context,
    LabelPrintState state,
    LabelPrintController controller,
    CustomLabelData data,
    LabelComponent component,
  ) {
    final key = component.fieldKey!;
    final label = LabelFieldKey.label(key);

    final isPackedField = key == LabelFieldKey.packedDate || key == LabelFieldKey.packedTime;
    final isUseByField = key == LabelFieldKey.useByDate || key == LabelFieldKey.useByTime;

    if (isUseByField) {
      // Derived from the Use By quick-select in PrintDetailsPanel; shown
      // here read-only so the user can see it inline with the other fields.
      return _ReadOnlyField(label: label, value: data.resolve(component));
    }

    if (isPackedField) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _pickPackedAt(context, controller, data.packedAt),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('$label: ${_dateTimeFormat.format(data.packedAt)}'),
              ),
              const Icon(Icons.edit_calendar_outlined, size: 18, color: Colors.black45),
            ],
          ),
        ),
      );
    }

    return TextFormField(
      key: ValueKey('$key-${state.formGeneration}'),
      initialValue: data.fieldValues[key] ?? component.value ?? '',
      decoration: InputDecoration(labelText: label),
      onChanged: (value) => controller.updateCustomFieldValue(key, value),
    );
  }

  Future<void> _pickPackedAt(
    BuildContext context,
    LabelPrintController controller,
    DateTime current,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 1),
      lastDate: DateTime(current.year + 1),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;

    controller.updateCustomPackedAt(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value'),
    );
  }
}
