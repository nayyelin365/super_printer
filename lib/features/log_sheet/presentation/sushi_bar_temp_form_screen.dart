import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/sushi_bar_temp_record.dart';
import 'log_record_controller.dart';
import 'widgets/log_form_fields.dart';

/// Routed at `/logs/sushiBarTemp/entry` — create/edit one Sushi Bar Temp
/// Log reading (`editingLogRecordProvider` null = new).
class SushiBarTempFormScreen extends ConsumerStatefulWidget {
  const SushiBarTempFormScreen({super.key});

  @override
  ConsumerState<SushiBarTempFormScreen> createState() => _SushiBarTempFormScreenState();
}

class _SushiBarTempFormScreenState extends ConsumerState<SushiBarTempFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _formGeneration = 0;

  late DateTime _date;
  String? _locationId;
  String _locationName = '';
  TempTimeSlot _timeSlot = TempTimeSlot.nineAm;
  String _displayCase = '';
  String _cooler = '';
  String _freezer = '';
  bool _calibrated = false;
  String _initials = '';
  bool _isSaving = false;

  SushiBarTempRecord? get _editing => ref.read(editingLogRecordProvider) as SushiBarTempRecord?;

  @override
  void initState() {
    super.initState();
    final e = _editing;
    final now = DateTime.now();
    _date = e?.date ?? DateTime(now.year, now.month, now.day);
    _locationId = e?.locationId;
    _locationName = e?.locationName ?? '';
    _timeSlot = e?.timeSlot ?? TempTimeSlot.nineAm;
    _displayCase = e?.displayCaseTempF?.toString() ?? '';
    _cooler = e?.coolerTempF?.toString() ?? '';
    _freezer = e?.freezerTempF?.toString() ?? '';
    _calibrated = e?.calibrated ?? false;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final editing = _editing;
    final record = SushiBarTempRecord(
      id: editing?.id ?? '',
      date: _date,
      locationId: _locationId!,
      locationName: _locationName,
      timeSlot: _timeSlot,
      displayCaseTempF: _num(_displayCase),
      coolerTempF: _num(_cooler),
      freezerTempF: _num(_freezer),
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
        _displayCase = '';
        _cooler = '';
        _freezer = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editing != null;
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
                          LogLocationField(
                            locationId: _locationId,
                            onChanged: (id, name) => setState(() {
                              _locationId = id;
                              _locationName = name;
                            }),
                          ),
                          LogNumberField(
                            label: 'Display Case',
                            initialValue: _displayCase,
                            formKeySuffix: '$_formGeneration',
                            onChanged: (v) => _displayCase = v,
                          ),
                          LogNumberField(
                            label: 'Cooler',
                            initialValue: _cooler,
                            formKeySuffix: '$_formGeneration',
                            onChanged: (v) => _cooler = v,
                          ),
                          LogNumberField(
                            label: 'Freezer',
                            initialValue: _freezer,
                            formKeySuffix: '$_formGeneration',
                            onChanged: (v) => _freezer = v,
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
