import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/log_record.dart';
import '../domain/rice_hot_hold_record.dart';
import 'log_record_controller.dart';
import 'widgets/log_form_fields.dart';

/// Routed at `/logs/riceHotHold/entry` — create/edit one Rice Hot Holding
/// Log row (start temp + the +2 / +4 / +6 hour checks).
class RiceHotHoldFormScreen extends ConsumerStatefulWidget {
  const RiceHotHoldFormScreen({super.key});

  @override
  ConsumerState<RiceHotHoldFormScreen> createState() => _RiceHotHoldFormScreenState();
}

class _RiceHotHoldFormScreenState extends ConsumerState<RiceHotHoldFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _formGeneration = 0;

  String _foodItemName = '';
  String _batchNo = '';
  DateTime? _start;
  String _startInitials = '';
  String _actualTemp = '';
  String _actualTempInitials = '';
  late Map<int, DayTime?> _checkTimes;
  late Map<int, String> _checkTemps;
  late Map<int, String> _checkInitials;
  DayTime? _finishedTime;
  DayTime? _discardTime;
  String _correctiveAction = '';
  String _initials = '';
  bool _isSaving = false;

  RiceHotHoldRecord? get _editing => ref.read(editingLogRecordProvider) as RiceHotHoldRecord?;

  @override
  void initState() {
    super.initState();
    final e = _editing;
    _foodItemName = e?.foodItemName ?? '';
    _batchNo = e?.batchNo ?? '';
    _start = e?.start;
    _startInitials = e?.startInitials ?? '';
    _actualTemp = e?.actualTempF?.toString() ?? '';
    _actualTempInitials = e?.actualTempInitials ?? '';
    _finishedTime = e?.finishedTime;
    _discardTime = e?.discardTime;
    _correctiveAction = e?.correctiveAction ?? '';
    _initials = e?.initials ?? '';
    _checkTimes = {for (final h in riceHotHoldOffsets) h: e?.checkAt(h).time};
    _checkTemps = {for (final h in riceHotHoldOffsets) h: e?.checkAt(h).tempF?.toString() ?? ''};
    _checkInitials = {for (final h in riceHotHoldOffsets) h: e?.checkAt(h).initials ?? ''};
    if (e == null) {
      ref.read(logRecordControllerProvider).lastUsedInitials().then((last) {
        if (mounted && last != null && _initials.isEmpty) setState(() => _initials = last);
      });
    }
  }

  double? _num(String s) => double.tryParse(s.trim());

  DateTime get _recordDate {
    final d = _start ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final editing = _editing;
    final record = RiceHotHoldRecord(
      id: editing?.id ?? '',
      date: _recordDate,
      foodItemName: _foodItemName.trim(),
      batchNo: _batchNo.trim(),
      start: _start,
      startInitials: _startInitials.trim(),
      actualTempF: _num(_actualTemp),
      actualTempInitials: _actualTempInitials.trim(),
      checks: [
        for (final h in riceHotHoldOffsets)
          RiceHotHoldCheck(
            hourOffset: h,
            time: _checkTimes[h],
            tempF: _num(_checkTemps[h] ?? ''),
            initials: (_checkInitials[h] ?? '').trim(),
          ),
      ],
      finishedTime: _finishedTime,
      discardTime: _discardTime,
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
        _start = null;
        _startInitials = '';
        _actualTemp = '';
        _actualTempInitials = '';
        _finishedTime = null;
        _discardTime = null;
        _correctiveAction = '';
        _checkTimes = {for (final h in riceHotHoldOffsets) h: null};
        _checkTemps = {for (final h in riceHotHoldOffsets) h: ''};
        _checkInitials = {for (final h in riceHotHoldOffsets) h: ''};
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
              title: isEditing ? 'Edit Hot Holding Entry' : 'New Hot Holding Entry',
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
                          LogFoodField(value: _foodItemName, onChanged: (v) => _foodItemName = v),
                          const LogFieldLabel('Batch No'),
                          TextFormField(
                            initialValue: _batchNo,
                            decoration: const InputDecoration(hintText: 'e.g. Batch-2026-0002'),
                            onChanged: (v) => _batchNo = v,
                          ),
                          const SizedBox(height: 12),
                          LogPickerField(
                            label: 'Start (date & time)',
                            value: _start == null
                                ? 'Not set'
                                : logFormDateTimeFormat.format(_start!),
                            onTap: () async {
                              final picked =
                                  await pickLogDateTime(context, _start ?? DateTime.now());
                              if (picked != null) setState(() => _start = picked);
                            },
                            onClear: _start == null ? null : () => setState(() => _start = null),
                          ),
                          const LogFieldLabel('Start Initial'),
                          TextFormField(
                            key: ValueKey('start-initials-$_formGeneration'),
                            initialValue: _startInitials,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(hintText: 'e.g. NL'),
                            onChanged: (v) => _startInitials = v,
                          ),
                          const SizedBox(height: 12),
                          LogNumberField(
                            label: 'Actual Temp °F (at start)',
                            initialValue: _actualTemp,
                            hint: 'e.g. 170',
                            formKeySuffix: '$_formGeneration',
                            onChanged: (v) => _actualTemp = v,
                          ),
                          const LogFieldLabel('Actual Temp Initial'),
                          TextFormField(
                            key: ValueKey('actual-temp-initials-$_formGeneration'),
                            initialValue: _actualTempInitials,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(hintText: 'e.g. NL'),
                            onChanged: (v) => _actualTempInitials = v,
                          ),
                          const SizedBox(height: 12),
                          for (final h in riceHotHoldOffsets) ...[
                            const Divider(height: 24),
                            Text(
                              '+$h hours',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            LogPickerField(
                              label: 'Time',
                              value: _checkTimes[h]?.label ?? 'Not set',
                              onTap: () async {
                                final t = await pickLogTime(context, _checkTimes[h]);
                                if (t != null) setState(() => _checkTimes[h] = t);
                              },
                              onClear: _checkTimes[h] == null
                                  ? null
                                  : () => setState(() => _checkTimes[h] = null),
                            ),
                            LogNumberField(
                              label: 'Temp',
                              initialValue: _checkTemps[h] ?? '',
                              hint: 'e.g. 150',
                              formKeySuffix: '$_formGeneration-$h',
                              onChanged: (v) => _checkTemps[h] = v,
                            ),
                            LogFieldLabel('Initial (+$h hr)'),
                            TextFormField(
                              key: ValueKey('check-init-$h-$_formGeneration'),
                              initialValue: _checkInitials[h],
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(hintText: 'e.g. NL'),
                              onChanged: (v) => _checkInitials[h] = v,
                            ),
                          ],
                          const Divider(height: 24),
                          LogPickerField(
                            label: 'Finished Time',
                            value: _finishedTime?.label ?? 'Not set',
                            onTap: () async {
                              final t = await pickLogTime(context, _finishedTime);
                              if (t != null) setState(() => _finishedTime = t);
                            },
                            onClear: _finishedTime == null
                                ? null
                                : () => setState(() => _finishedTime = null),
                          ),
                          LogPickerField(
                            label: 'Discard Time',
                            value: _discardTime?.label ?? 'Not set',
                            onTap: () async {
                              final t = await pickLogTime(context, _discardTime);
                              if (t != null) setState(() => _discardTime = t);
                            },
                            onClear: _discardTime == null
                                ? null
                                : () => setState(() => _discardTime = null),
                          ),
                          const LogFieldLabel('Corrective Action'),
                          TextFormField(
                            initialValue: _correctiveAction,
                            maxLines: 2,
                            decoration: const InputDecoration(hintText: 'e.g. Reheated to 165°F'),
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
