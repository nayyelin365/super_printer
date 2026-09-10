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
  final bool value;
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

/// Location dropdown backed by [logLocationsProvider], with an inline
/// "Add New Location" dialog — the same UX as the old entry form. Calls
/// [onChanged] with the picked location's id + name.
class LogLocationField extends ConsumerWidget {
  const LogLocationField({
    super.key,
    required this.locationId,
    required this.onChanged,
  });

  final String? locationId;
  final void Function(String id, String name) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(logLocationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LogFieldLabel('Store / Unit Location'),
        locationsAsync.when(
          data: (locations) => DropdownButtonFormField<String>(
            initialValue: locations.any((l) => l.id == locationId) ? locationId : null,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'Select a location'),
            items: [
              for (final location in locations)
                DropdownMenuItem(
                  value: location.id,
                  child: Text(location.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              final location = locations.firstWhere((l) => l.id == id);
              onChanged(location.id, location.name);
            },
            validator: (value) => value == null ? 'Select a location' : null,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => const Text(
            'Could not load locations.',
            style: TextStyle(color: AppTheme.danger, fontSize: 12),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addLocation(context, ref),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add New Location'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _addLocation(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    var name = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Location'),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Location Name'),
            onChanged: (value) => name = value,
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Enter a location name' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(name.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final location = await ref.read(logRecordControllerProvider).addLocation(result);
    onChanged(location.id, location.name);
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

/// Time-of-day picker returning a [DayTime].
Future<DayTime?> pickLogTime(BuildContext context, DayTime? current) async {
  final now = current ?? const DayTime(9, 0);
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
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
