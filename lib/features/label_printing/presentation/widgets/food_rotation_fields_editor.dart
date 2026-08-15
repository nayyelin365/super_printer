import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/food_rotation_label_data.dart';
import '../label_print_controller.dart';

/// Editable fields for the "Food Rotation Label" template, shown under the
/// live preview. Deliberately has none of the Poke Bowl template's
/// weight/price/barcode fields.
class FoodRotationFieldsEditor extends ConsumerWidget {
  const FoodRotationFieldsEditor({super.key});

  static final _dateTimeFormat = DateFormat('MM/dd/yyyy hh:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelPrintControllerProvider);
    final controller = ref.read(labelPrintControllerProvider.notifier);
    final data = state.labelData as FoodRotationLabelData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: ValueKey('food-${state.formGeneration}'),
          initialValue: data.foodName,
          decoration: const InputDecoration(labelText: 'Food Name'),
          onChanged: controller.updateFoodName,
        ),
        const SizedBox(height: 12),
        Text(
          'Prep Date & Time',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pickPrepDateTime(context, controller, data.prepDateTime),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(child: Text(_dateTimeFormat.format(data.prepDateTime))),
                const Icon(Icons.edit_calendar_outlined, size: 18, color: Colors.black45),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('employee-${state.formGeneration}'),
          initialValue: data.employee,
          decoration: const InputDecoration(labelText: 'Employee'),
          onChanged: controller.updateEmployee,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text('Show PH', style: TextStyle(fontSize: 13)),
            ),
            Switch(
              value: data.showPh,
              onChanged: controller.toggleShowPh,
            ),
          ],
        ),
        if (data.showPh)
          TextFormField(
            key: ValueKey('ph-${state.formGeneration}'),
            initialValue: data.ph,
            decoration: const InputDecoration(labelText: 'PH'),
            onChanged: controller.updatePh,
          ),
      ],
    );
  }

  Future<void> _pickPrepDateTime(
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

    controller.updatePrepDateTime(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}
