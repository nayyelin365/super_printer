import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/cooling_record.dart';
import '../domain/log_record.dart';
import 'log_record_controller.dart';
import 'widgets/log_form_fields.dart';

/// Routed at `/logs/cooling/entry` — create/edit one Cooling Log row.
class CoolingFormScreen extends ConsumerStatefulWidget {
  const CoolingFormScreen({super.key});

  @override
  ConsumerState<CoolingFormScreen> createState() => _CoolingFormScreenState();
}

class _CoolingFormScreenState extends ConsumerState<CoolingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _formGeneration = 0;

  String _foodItemName = '';
  String _batchNo = '';
  DateTime? _coolingStart;
  String _initialTemp = '';
  DayTime? _stage1Time;
  String _stage1Temp = '';
  String _stage1Initials = '';
  DayTime? _stage2Time;
  String _stage2Temp = '';
  String _stage2Initials = '';
  String _correctiveAction = '';
  String _initials = '';
  bool _isSaving = false;

  CoolingRecord? get _editing => ref.read(editingLogRecordProvider) as CoolingRecord?;

  @override
  void initState() {
    super.initState();
    final e = _editing;
    _foodItemName = e?.foodItemName ?? '';
    _batchNo = e?.batchNo ?? '';
    _coolingStart = e?.coolingStart;
    _initialTemp = e?.initialTempF?.toString() ?? '';
    _stage1Time = e?.stage1Time;
    _stage1Temp = e?.stage1TempF?.toString() ?? '';
    _stage1Initials = e?.stage1Initials ?? '';
    _stage2Time = e?.stage2Time;
    _stage2Temp = e?.stage2TempF?.toString() ?? '';
    _stage2Initials = e?.stage2Initials ?? '';
    _correctiveAction = e?.correctiveAction ?? '';
    _initials = e?.initials ?? '';
    if (e == null) {
      ref.read(logRecordControllerProvider).lastUsedInitials().then((last) {
        if (mounted && last != null && _initials.isEmpty) setState(() => _initials = last);
      });
    }
  }

  double? _num(String s) => double.tryParse(s.trim());

  DateTime get _recordDate {
    final d = _coolingStart ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final editing = _editing;
    final record = CoolingRecord(
      id: editing?.id ?? '',
      date: _recordDate,
      foodItemName: _foodItemName.trim(),
      batchNo: _batchNo.trim(),
      coolingStart: _coolingStart,
      initialTempF: _num(_initialTemp),
      stage1Time: _stage1Time,
      stage1TempF: _num(_stage1Temp),
      stage1Initials: _stage1Initials.trim(),
      stage2Time: _stage2Time,
      stage2TempF: _num(_stage2Temp),
      stage2Initials: _stage2Initials.trim(),
      correctiveAction: _correctiveAction.trim(),
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
        _foodItemName = '';
        _batchNo = '';
        _coolingStart = null;
        _initialTemp = '';
        _stage1Time = null;
        _stage1Temp = '';
        _stage2Time = null;
        _stage2Temp = '';
        _correctiveAction = '';
        // Stage 1/2 Initial are intentionally kept — the same person is
        // usually the one taking the next cooling reading too.
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
              title: isEditing ? 'Edit Cooling Entry' : 'New Cooling Entry',
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
                          LogFoodField(
                            value: _foodItemName,
                            onChanged: (v) => _foodItemName = v,
                          ),
                          const LogFieldLabel('Batch No'),
                          TextFormField(
                            initialValue: _batchNo,
                            decoration: const InputDecoration(hintText: 'e.g. Batch-2026-0002'),
                            onChanged: (v) => _batchNo = v,
                          ),
                          const SizedBox(height: 12),
                          LogPickerField(
                            label: 'Cooling Start (date & time)',
                            value: _coolingStart == null
                                ? 'Not set'
                                : logFormDateTimeFormat.format(_coolingStart!),
                            onTap: () async {
                              final picked =
                                  await pickLogDateTime(context, _coolingStart ?? DateTime.now());
                              if (picked != null) setState(() => _coolingStart = picked);
                            },
                            onClear: _coolingStart == null
                                ? null
                                : () => setState(() => _coolingStart = null),
                          ),
                          LogNumberField(
                            label: 'Initial Temp',
                            initialValue: _initialTemp,
                            hint: 'e.g. 170',
                            formKeySuffix: '$_formGeneration',
                            onChanged: (v) => _initialTemp = v,
                          ),
                          _TimeRow(
                            label: 'Stage 1 — 135°F → 70°F (within 2 hr)',
                            time: _stage1Time,
                            onPick: () async {
                              final t = await pickLogTime(context, _stage1Time);
                              if (t != null) setState(() => _stage1Time = t);
                            },
                            onClear: () => setState(() => _stage1Time = null),
                          ),
                          LogNumberField(
                            label: 'Stage 1 Temp',
                            initialValue: _stage1Temp,
                            hint: 'e.g. 68',
                            formKeySuffix: '$_formGeneration',
                            onChanged: (v) => _stage1Temp = v,
                          ),
                          const LogFieldLabel('Stage 1 Initial'),
                          TextFormField(
                            key: ValueKey('stage1initials-$_formGeneration'),
                            initialValue: _stage1Initials,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(hintText: 'e.g. NL'),
                            onChanged: (v) => _stage1Initials = v,
                          ),
                          const SizedBox(height: 12),
                          _TimeRow(
                            label: 'Stage 2 — ≤ 41°F (within total 6 hr)',
                            time: _stage2Time,
                            onPick: () async {
                              final t = await pickLogTime(context, _stage2Time);
                              if (t != null) setState(() => _stage2Time = t);
                            },
                            onClear: () => setState(() => _stage2Time = null),
                          ),
                          LogNumberField(
                            label: 'Stage 2 Temp',
                            initialValue: _stage2Temp,
                            hint: 'e.g. 40',
                            formKeySuffix: '$_formGeneration',
                            onChanged: (v) => _stage2Temp = v,
                          ),
                          const LogFieldLabel('Stage 2 Initial'),
                          TextFormField(
                            key: ValueKey('stage2initials-$_formGeneration'),
                            initialValue: _stage2Initials,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(hintText: 'e.g. NL'),
                            onChanged: (v) => _stage2Initials = v,
                          ),
                          const SizedBox(height: 12),
                          const LogFieldLabel('Corrective Action'),
                          TextFormField(
                            initialValue: _correctiveAction,
                            maxLines: 2,
                            decoration: const InputDecoration(hintText: 'e.g. Discarded — over 2 hr'),
                            onChanged: (v) => _correctiveAction = v,
                          ),
                          const SizedBox(height: 12),
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

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.time,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DayTime? time;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return LogPickerField(
      label: label,
      value: time?.label ?? 'Not set',
      onTap: onPick,
      onClear: time == null ? null : onClear,
    );
  }
}
