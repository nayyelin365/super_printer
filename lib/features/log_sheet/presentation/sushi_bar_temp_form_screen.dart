import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/log_location.dart';
import '../domain/sushi_bar_temp_record.dart';
import 'log_record_controller.dart';
import 'widgets/log_form_fields.dart';

/// Routed at `/logs/sushiBarTemp/entry` — create/edit one Sushi Bar Temp
/// Log reading (`editingLogRecordProvider` null = new).
///
/// The temperature fields are not fixed (Display Case / Cooler / Freezer)
/// — one number field is rendered per unit in the shared
/// `logLocationsProvider` list, so a kitchen with 5 tracked units types 5
/// temperatures and one with 2 types 2. "+ Add Unit Location" adds a new
/// unit to that shared list (via [LogRecordController.addLocation]); it
/// then shows up here, and everywhere else that reads the same list,
/// immediately.
class SushiBarTempFormScreen extends ConsumerStatefulWidget {
  const SushiBarTempFormScreen({super.key});

  @override
  ConsumerState<SushiBarTempFormScreen> createState() => _SushiBarTempFormScreenState();
}

class _SushiBarTempFormScreenState extends ConsumerState<SushiBarTempFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _formGeneration = 0;

  late DateTime _date;
  TempTimeSlot _timeSlot = TempTimeSlot.nineAm;

  /// Typed temperature text, keyed by unit/location id — populated from
  /// the editing record's readings up front, then filled in as the user
  /// types into each unit's field (rendered from `logLocationsProvider`,
  /// not from this map, so a brand-new unit shows up with an empty field).
  final Map<String, String> _tempByLocationId = {};

  bool? _calibrated;
  String _initials = '';
  bool _isSaving = false;

  SushiBarTempRecord? get _editing => ref.read(editingLogRecordProvider) as SushiBarTempRecord?;

  @override
  void initState() {
    super.initState();
    final e = _editing;
    final now = DateTime.now();
    _date = e?.date ?? DateTime(now.year, now.month, now.day);
    _timeSlot = e?.timeSlot ?? TempTimeSlot.nineAm;
    for (final reading in e?.readings ?? const []) {
      if (reading.tempF != null) {
        _tempByLocationId[reading.locationId] = reading.tempF!.toString();
      }
    }
    _calibrated = e?.calibrated;
    _initials = e?.initials ?? '';
    if (e == null) {
      ref.read(logRecordControllerProvider).lastUsedInitials().then((last) {
        if (mounted && last != null && _initials.isEmpty) setState(() => _initials = last);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  double? _num(String s) => double.tryParse(s.trim());

  Future<void> _addUnitLocation() async {
    final formKey = GlobalKey<FormState>();
    var name = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Unit Location'),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Sushi Case 2'),
            onChanged: (value) => name = value,
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Enter a unit name' : null,
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
    await ref.read(logRecordControllerProvider).addLocation(result);
    // The new unit shows up on its own once `logLocationsProvider` re-emits
    // — nothing else to do here.
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final locations = ref.read(logLocationsProvider).valueOrNull ?? const <LogLocation>[];
    final editing = _editing;
    final record = SushiBarTempRecord(
      id: editing?.id ?? '',
      date: _date,
      timeSlot: _timeSlot,
      readings: [
        for (final location in locations)
          UnitTempReading(
            locationId: location.id,
            locationName: location.name,
            tempF: _num(_tempByLocationId[location.id] ?? ''),
          ),
      ],
      calibrated: _calibrated,
      initials: _initials.trim(),
      createdAt: editing?.createdAt,
      updatedAt: editing?.updatedAt,
    );

    final saved = await submitLogRecord(
      context: context,
      ref: ref,
      isEditing: editing != null,
      record: record,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!saved) return;
    if (editing != null) {
      context.pop();
    } else {
      setState(() {
        _formGeneration++;
        _tempByLocationId.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editing != null;
    final locationsAsync = ref.watch(logLocationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LogFormHeader(
              title: isEditing ? 'Edit Temp Reading' : 'New Temp Reading',
              isSaving: _isSaving,
              onSave: _save,
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
                          LogPickerField(
                            label: 'Date',
                            value: logFormDateFormat.format(_date),
                            onTap: _pickDate,
                          ),
                          const LogFieldLabel('Time'),
                          DropdownButtonFormField<TempTimeSlot>(
                            initialValue: _timeSlot,
                            items: [
                              for (final slot in TempTimeSlot.values)
                                DropdownMenuItem(value: slot, child: Text(slot.label)),
                            ],
                            onChanged: (v) => setState(() => _timeSlot = v ?? _timeSlot),
                          ),
                          const SizedBox(height: 12),
                          locationsAsync.when(
                            data: (locations) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final location in locations)
                                  LogNumberField(
                                    label: location.name,
                                    initialValue: _tempByLocationId[location.id] ?? '',
                                    formKeySuffix: '${location.id}-$_formGeneration',
                                    onChanged: (v) => _tempByLocationId[location.id] = v,
                                  ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _addUnitLocation,
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Unit Location'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (error, _) => const Text(
                              'Could not load unit locations.',
                              style: TextStyle(color: AppTheme.danger, fontSize: 12),
                            ),
                          ),
                          LogYesNoField(
                            label: 'Thermometer Calibrated',
                            value: _calibrated,
                            onChanged: (v) => setState(() => _calibrated = v),
                          ),
                          const LogFieldLabel('Initial'),
                          TextFormField(
                            key: ValueKey('initials-$_initials'),
                            initialValue: _initials,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(hintText: 'e.g. NL'),
                            onChanged: (v) => _initials = v,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Enter initials' : null,
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
