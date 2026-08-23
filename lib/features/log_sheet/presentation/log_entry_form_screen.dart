import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../food_selection/presentation/food_selection_controller.dart';
import '../domain/log_entry.dart';
import '../domain/log_type.dart';
import 'log_controller.dart';

/// Routed at `/logs/:logType/entry` — create or edit a log entry, driven
/// by [editingLogEntryProvider] (null means "creating a new entry",
/// mirroring the alarm/template editor screens' pattern).
class LogEntryFormScreen extends ConsumerStatefulWidget {
  const LogEntryFormScreen({super.key, required this.logType});

  final LogType logType;

  @override
  ConsumerState<LogEntryFormScreen> createState() => _LogEntryFormScreenState();
}

class _LogEntryFormScreenState extends ConsumerState<LogEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late int _hour;
  late int _minute;
  String? _foodName;
  double? _targetTemp;
  String? _locationId;
  String? _locationName;
  String _actualTempText = '';
  PassFail? _passFail;
  String _correctiveAction = '';
  String _initials = '';
  bool _isSaving = false;

  /// Bumped whenever the form is reset after a create-and-stay save — used
  /// as a key on the field column so every `TextFormField` remounts with
  /// its fresh `initialValue` instead of keeping stale typed text.
  int _formGeneration = 0;

  LogEntry? get _editing => ref.read(editingLogEntryProvider);

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    final now = DateTime.now();
    _date = editing?.date ?? DateTime(now.year, now.month, now.day);
    _hour = editing?.hour ?? now.hour;
    _minute = editing?.minute ?? now.minute;
    _foodName = editing?.foodName;
    _targetTemp = editing?.targetTemp;
    _locationId = editing?.locationId;
    _locationName = editing?.locationName;
    _actualTempText = editing?.actualTemp.toString() ?? '';
    _passFail = editing?.passFail;
    _correctiveAction = editing?.correctiveAction ?? '';
    _initials = editing?.initials ?? '';

    if (editing == null) {
      // Pre-fill initials from the last entry saved, so it doesn't need
      // retyping every time — this app has no login/employee-identity
      // system to pull it from instead.
      ref.read(logControllerProvider).lastUsedInitials().then((last) {
        if (mounted && last != null && _initials.isEmpty) {
          setState(() => _initials = last);
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  void _selectFood(String? name) {
    setState(() {
      _foodName = name;
      final food = name == null
          ? null
          : ref.read(foodCatalogProvider).where((f) => f.name == name).firstOrNull;
      _targetTemp = food?.targetTemperature;
    });
  }

  Future<void> _addLocation() async {
    final formKey = GlobalKey<FormState>();
    var name = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
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
        );
      },
    );

    if (result == null || result.isEmpty || !mounted) return;
    final location = await ref.read(logControllerProvider).addLocation(result);
    if (mounted) {
      setState(() {
        _locationId = location.id;
        _locationName = location.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }
    if (_passFail == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select Pass or Fail.')));
      return;
    }
    if (_passFail == PassFail.fail && _correctiveAction.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corrective action is required when the check fails.')),
      );
      return;
    }

    // Best-effort — if the connectivity check itself fails for any reason
    // (e.g. platform channel not yet available), fall through to the actual
    // save attempt rather than blocking the button on a broken pre-check.
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((result) => result == ConnectivityResult.none)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Check your network and try again.'),
          ),
        );
        return;
      }
    } catch (_) {
      // Ignore — the save attempt below will surface a real error if the
      // connection actually is the problem.
    }

    setState(() => _isSaving = true);

    try {
      final editing = _editing;
      final entry = LogEntry(
        id: editing?.id ?? '',
        logType: widget.logType,
        date: _date,
        hour: _hour,
        minute: _minute,
        foodName: _foodName!,
        targetTemp: _targetTemp,
        locationId: _locationId!,
        locationName: _locationName!,
        actualTemp: double.parse(_actualTempText),
        passFail: _passFail!,
        correctiveAction: _correctiveAction.trim(),
        initials: _initials.trim(),
      );

      final controller = ref.read(logControllerProvider);
      if (editing == null) {
        await controller.addEntry(entry);
      } else {
        await controller.updateEntry(entry);
      }
      if (!mounted) return;
      if (editing == null) {
        // Stay on the form (cleared) rather than popping — logging several
        // entries back-to-back is the common case, and this avoids
        // reopening the form each time.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Log entry saved.')));
        _resetForNextEntry();
      } else {
        context.pop();
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is FirebaseException && error.code == 'unavailable'
          ? 'Could not reach the server. Check your internet connection and try again.'
          : 'Could not save: $error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForNextEntry() {
    final now = DateTime.now();
    setState(() {
      _formGeneration++;
      _date = DateTime(now.year, now.month, now.day);
      _hour = now.hour;
      _minute = now.minute;
      _foodName = null;
      _targetTemp = null;
      _locationId = null;
      _locationName = null;
      _actualTempText = '';
      _passFail = null;
      _correctiveAction = '';
      // _initials is intentionally kept — the same person is usually the
      // one logging the next entry too.
    });
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodCatalogProvider);
    final locationsAsync = ref.watch(logLocationsProvider);
    final isEditing = _editing != null;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                  Text(
                    isEditing ? 'Edit ${widget.logType.label}' : 'New ${widget.logType.label}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Saving...'),
                            ],
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        key: ValueKey(_formGeneration),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _PickerField(
                                  label: 'Date',
                                  value:
                                      '${_date.month.toString().padLeft(2, '0')}/'
                                      '${_date.day.toString().padLeft(2, '0')}/${_date.year}',
                                  onTap: _pickDate,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PickerField(
                                  label: 'Time',
                                  value: TimeOfDay(hour: _hour, minute: _minute).format(context),
                                  onTap: _pickTime,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          const _FieldLabel('Food'),
                          DropdownButtonFormField<String>(
                            initialValue: _foodName,
                            isExpanded: true,
                            decoration: const InputDecoration(hintText: 'Select a food'),
                            items: [
                              for (final food in foods)
                                DropdownMenuItem(
                                  value: food.name,
                                  child: Text(food.name, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: _selectFood,
                            validator: (value) => value == null ? 'Select a food' : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Target Temp: ${_targetTemp == null ? '-' : '${_targetTemp!.toStringAsFixed(0)}°F'}',
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                          const SizedBox(height: 16),

                          const _FieldLabel('Unit Name / Location'),
                          locationsAsync.when(
                            data: (locations) => DropdownButtonFormField<String>(
                              initialValue: _locationId,
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
                                final location = locations.firstWhere((l) => l.id == id);
                                setState(() {
                                  _locationId = location.id;
                                  _locationName = location.name;
                                });
                              },
                              validator: (value) => value == null ? 'Select a location' : null,
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (error, stackTrace) => Text(
                              'Could not load locations.',
                              style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _addLocation,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add New Location'),
                            ),
                          ),
                          const SizedBox(height: 8),

                          const _FieldLabel('Actual Temp'),
                          TextFormField(
                            initialValue: _actualTempText,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: 'e.g. 38', suffixText: '°F'),
                            onChanged: (value) => _actualTempText = value,
                            validator: (value) => (value == null || double.tryParse(value) == null)
                                ? 'Enter a valid temperature'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          const _FieldLabel('Pass / Fail'),
                          Row(
                            children: [
                              Expanded(
                                child: _PassFailButton(
                                  label: 'PASS',
                                  color: AppTheme.success,
                                  selected: _passFail == PassFail.pass,
                                  onTap: () => setState(() => _passFail = PassFail.pass),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PassFailButton(
                                  label: 'FAIL',
                                  color: AppTheme.danger,
                                  selected: _passFail == PassFail.fail,
                                  onTap: () => setState(() => _passFail = PassFail.fail),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _FieldLabel(
                            _passFail == PassFail.fail
                                ? 'Corrective Action (required)'
                                : 'Corrective Action (optional)',
                          ),
                          TextFormField(
                            initialValue: _correctiveAction,
                            maxLines: 2,
                            decoration: const InputDecoration(hintText: 'e.g. Moved to walk-in'),
                            onChanged: (value) => setState(() => _correctiveAction = value),
                          ),
                          const SizedBox(height: 16),

                          const _FieldLabel('Employee / Initials'),
                          TextFormField(
                            key: ValueKey('initials-$_initials'),
                            initialValue: _initials,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(hintText: 'e.g. NL'),
                            onChanged: (value) => _initials = value,
                            validator: (value) =>
                                (value == null || value.trim().isEmpty) ? 'Enter initials' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _PassFailButton extends StatelessWidget {
  const _PassFailButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.black54,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }
}
