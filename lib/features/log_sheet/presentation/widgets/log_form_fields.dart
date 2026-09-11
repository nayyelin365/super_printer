import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/network_error.dart';
import '../../../food_selection/presentation/food_selection_controller.dart';
import '../../domain/log_record.dart';
import '../log_record_controller.dart';

/// Small building blocks shared by the four log form screens — promoted
/// from the old single `LogEntryFormScreen` so every form looks and
/// behaves the same (labels, pickers, Yes/No toggles, the location
/// dropdown + "Add New Location" dialog, the sticky Save header).

final logFormDateFormat = DateFormat('MM/dd/yyyy');
final logFormDateTimeFormat = DateFormat('MM/dd/yyyy h:mm a');

class LogFieldLabel extends StatelessWidget {
  const LogFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }
}

/// A read-only field that opens a picker on tap (date, time, date+time).
class LogPickerField extends StatelessWidget {
  const LogPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LogFieldLabel(label),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: onClear == null
                  ? const Icon(Icons.event, size: 18)
                  : IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear',
                    ),
            ),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Yes / No toggle styled like the old `_PassFailButton`.
class LogYesNoField extends StatelessWidget {
  const LogYesNoField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;

  /// Null means "not answered yet" — neither pill is shown selected, and
  /// stays that way until the user actually taps one (no default answer).
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LogFieldLabel(label),
        Row(
          children: [
            Expanded(child: _pill(context, 'YES', true)),
            const SizedBox(width: 12),
            Expanded(child: _pill(context, 'NO', false)),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _pill(BuildContext context, String text, bool forValue) {
    final selected = value == forValue;
    final color = forValue ? AppTheme.success : AppTheme.danger;
    return InkWell(
      onTap: () => onChanged(forValue),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? color : Colors.black54,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Food-item field for the Cooling / Rice Hot Holding forms: an editable
/// combo box — pick from the "Item Lists" catalog ([foodCatalogProvider])
/// or type a name that isn't in it.
class LogFoodField extends ConsumerWidget {
  const LogFoodField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(foodCatalogProvider).map((f) => f.name).toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LogFieldLabel('Food Item Name'),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: value),
          optionsBuilder: (textValue) {
            final query = textValue.text.trim().toLowerCase();
            if (query.isEmpty) return names;
            return names.where((n) => n.toLowerCase().contains(query));
          },
          onSelected: onChanged,
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(hintText: 'Select or type a food name'),
              onChanged: onChanged,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a food item' : null,
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// The sticky "New / Edit ..." header with Cancel + Save (spinner while
/// saving) shared by every form screen.
class LogFormHeader extends StatelessWidget {
  const LogFormHeader({
    super.key,
    required this.title,
    required this.isSaving,
    required this.onSave,
  });

  final String title;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isSaving ? null : onSave,
            child: isSaving
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Text('Saving...'),
                    ],
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// A numeric (°F / pH) text field — returns null-safe parsing to the caller.
class LogNumberField extends StatelessWidget {
  const LogNumberField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.suffix = '°F',
    this.hint,
    this.formKeySuffix,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String suffix;
  final String? hint;
  final String? formKeySuffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LogFieldLabel(label),
        TextFormField(
          key: formKeySuffix == null ? null : ValueKey('num-$label-$formKeySuffix'),
          initialValue: initialValue,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: hint ?? 'e.g. 38', suffixText: suffix),
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Shows a date picker then a time picker, returning the combined
/// `DateTime` (or null if either step was cancelled).
Future<DateTime?> pickLogDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(initial.year - 2),
    lastDate: DateTime(initial.year + 2),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Time-of-day picker returning a [DayTime] — opens on [current] if the
/// field already has a value, otherwise on the actual current time (never
/// a fixed hour like 9:00) so a not-yet-set field starts from "now", the
/// most likely answer for something being logged as it happens.
Future<DayTime?> pickLogTime(BuildContext context, DayTime? current) async {
  final start = current ?? DayTime(TimeOfDay.now().hour, TimeOfDay.now().minute);
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
  );
  return time == null ? null : DayTime(time.hour, time.minute);
}

/// Shared save path for the four log forms: offline pre-check (shared
/// `network_error.dart`), create-or-update via [LogRecordController], and a
/// SnackBar. Returns true on a successful save so the caller can pop (edit)
/// or reset for the next entry (create).
Future<bool> submitLogRecord({
  required BuildContext context,
  required WidgetRef ref,
  required bool isEditing,
  required LogRecord record,
}) async {
  if (!await hasNetworkConnection()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Please check your internet connection.'),
        ),
      );
    }
    return false;
  }

  try {
    final controller = ref.read(logRecordControllerProvider);
    if (isEditing) {
      await controller.updateRecord(record);
    } else {
      await controller.addRecord(record);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? 'Entry updated.' : 'Entry saved.')),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(networkAwareErrorMessage(error))),
      );
    }
    return false;
  }
}
