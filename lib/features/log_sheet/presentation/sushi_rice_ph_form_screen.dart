import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/log_record.dart';
import '../domain/sushi_rice_ph_record.dart';
import 'log_record_controller.dart';
import 'widgets/log_form_fields.dart';

/// Routed at `/logs/sushiRicePh/entry` — create/edit one day's Sushi Rice
/// pH Log record. Standalone daily form; not connected to the guided Sushi
/// Rice Preparation SOP.
class SushiRicePhFormScreen extends ConsumerStatefulWidget {
  const SushiRicePhFormScreen({super.key});

  @override
  ConsumerState<SushiRicePhFormScreen> createState() => _SushiRicePhFormScreenState();
}

class _SushiRicePhFormScreenState extends ConsumerState<SushiRicePhFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _formGeneration = 0;

  late DateTime _date;
  String? _locationId;
  String _locationName = '';
  bool _phMeterCalibrated = false;
  String _riceBatchNo = '';
  DayTime? _timeStartCooking;
  DayTime? _timeCooked;
  DayTime? _timeAcidified;
  String _ricePh = '';
  bool _inRange = false;
  String _phAfterCorrected = '';
  String _amountVinegar = '';
  bool _inRangeAfterCorrection = false;
  bool _discardOutOfRange = false;
  DayTime? _timeRiceAllUsed;
  DayTime? _discardTimeAfterExpiry;
  String _initials = '';
  bool _isSaving = false;

  SushiRicePhRecord? get _editing => ref.read(editingLogRecordProvider) as SushiRicePhRecord?;

  @override
  void initState() {
    super.initState();
    final e = _editing;
    final now = DateTime.now();
    _date = e?.date ?? DateTime(now.year, now.month, now.day);
    _locationId = e?.locationId;
    _locationName = e?.locationName ?? '';
    _phMeterCalibrated = e?.phMeterCalibrated ?? false;
    _riceBatchNo = e?.riceBatchNo ?? '';
    _timeStartCooking = e?.timeStartCooking;
    _timeCooked = e?.timeCooked;
    _timeAcidified = e?.timeAcidified;
    _ricePh = e?.ricePh?.toString() ?? '';
    _inRange = e?.inRange ?? false;
    _phAfterCorrected = e?.phAfterCorrected?.toString() ?? '';
    _amountVinegar = e?.amountAddingVinegar ?? '';
    _inRangeAfterCorrection = e?.inRangeAfterCorrection ?? false;
    _discardOutOfRange = e?.discardOutOfRangeRice ?? false;
    _timeRiceAllUsed = e?.timeRiceAllUsed;
    _discardTimeAfterExpiry = e?.discardTimeAfterExpiry;
    _initials = e?.initials ?? '';
    if (e == null) {
      ref.read(logRecordControllerProvider).lastUsedInitials().then((last) {
        if (mounted && last != null && _initials.isEmpty) setState(() => _initials = last);
      });
    }
  }

  double? _num(String s) => double.tryParse(s.trim());

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Widget _time(String label, DayTime? value, ValueChanged<DayTime?> onChanged) {
    return LogPickerField(
      label: label,
      value: value?.label ?? 'Not set',
      onTap: () async {
        final t = await pickLogTime(context, value);
        if (t != null) onChanged(t);
      },
      onClear: value == null ? null : () => onChanged(null),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final editing = _editing;
    final record = SushiRicePhRecord(
      id: editing?.id ?? '',
      date: _date,
      locationId: _locationId!,
      locationName: _locationName,
      phMeterCalibrated: _phMeterCalibrated,
      riceBatchNo: _riceBatchNo.trim(),
      timeStartCooking: _timeStartCooking,
      timeCooked: _timeCooked,
      timeAcidified: _timeAcidified,
      ricePh: _num(_ricePh),
      inRange: _inRange,
      phAfterCorrected: _num(_phAfterCorrected),
      amountAddingVinegar: _amountVinegar.trim(),
      inRangeAfterCorrection: _inRangeAfterCorrection,
      discardOutOfRangeRice: _discardOutOfRange,
      timeRiceAllUsed: _timeRiceAllUsed,
      discardTimeAfterExpiry: _discardTimeAfterExpiry,
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
        _riceBatchNo = '';
        _timeStartCooking = null;
        _timeCooked = null;
        _timeAcidified = null;
        _ricePh = '';
        _inRange = false;
        _phAfterCorrected = '';
        _amountVinegar = '';
        _inRangeAfterCorrection = false;
        _discardOutOfRange = false;
        _timeRiceAllUsed = null;
        _discardTimeAfterExpiry = null;
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
              title: isEditing ? 'Edit pH Log Entry' : 'New pH Log Entry',
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
                          LogLocationField(
                            locationId: _locationId,
                            onChanged: (id, name) => setState(() {
                              _locationId = id;
                              _locationName = name;
                            }),
                          ),
                          LogYesNoField(
                            label: 'pH Meter Calibrated',
                            value: _phMeterCalibrated,
                            onChanged: (v) => setState(() => _phMeterCalibrated = v),
                          ),
                          const LogFieldLabel('Rice Batch No.'),
                          TextFormField(
                            initialValue: _riceBatchNo,
                            decoration: const InputDecoration(hintText: 'e.g. Batch-2026-0002'),
                            onChanged: (v) => _riceBatchNo = v,
                          ),
                          const SizedBox(height: 12),
                          _time('Time Rice Start Cooking', _timeStartCooking,
                              (v) => setState(() => _timeStartCooking = v)),
                          _time('Time Rice Cooked', _timeCooked,
                              (v) => setState(() => _timeCooked = v)),
                          _time('Time Acidified', _timeAcidified,
                              (v) => setState(() => _timeAcidified = v)),
                          LogNumberField(
                            label: 'Rice pH',
                            initialValue: _ricePh,
                            suffix: 'pH',
                            hint: 'e.g. 4.1',
                            formKeySuffix: '$_formGeneration',
                            onChanged: (v) => _ricePh = v,
                          ),
                          LogYesNoField(
                            label: 'Targeted pH 4.1 (max 4.2) — in range?',
                            value: _inRange,
                            onChanged: (v) => setState(() => _inRange = v),
                          ),
                          LogNumberField(
                            label: 'pH after Corrected',
                            initialValue: _phAfterCorrected,
                            suffix: 'pH',
                            hint: 'e.g. 4.1',
                            formKeySuffix: '$_formGeneration',
                            onChanged: (v) => _phAfterCorrected = v,
                          ),
                          const LogFieldLabel('Amount Adding More Vinegar'),
                          TextFormField(
                            key: ValueKey('vinegar-$_formGeneration'),
                            initialValue: _amountVinegar,
                            decoration: const InputDecoration(hintText: 'e.g. 50 ml'),
                            onChanged: (v) => _amountVinegar = v,
                          ),
                          const SizedBox(height: 12),
                          LogYesNoField(
                            label: 'In range after correction?',
                            value: _inRangeAfterCorrection,
                            onChanged: (v) => setState(() => _inRangeAfterCorrection = v),
                          ),
                          LogYesNoField(
                            label: 'Discard out of Range pH Rice',
                            value: _discardOutOfRange,
                            onChanged: (v) => setState(() => _discardOutOfRange = v),
                          ),
                          _time('Time Rice is all Used', _timeRiceAllUsed,
                              (v) => setState(() => _timeRiceAllUsed = v)),
                          _time('Discard Time after Expiry', _discardTimeAfterExpiry,
                              (v) => setState(() => _discardTimeAfterExpiry = v)),
                          const LogFieldLabel("Tester's Initial"),
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
