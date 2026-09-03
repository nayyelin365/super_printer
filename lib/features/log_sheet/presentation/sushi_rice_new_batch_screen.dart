import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/network_error.dart';
import '../../staff/presentation/staff_controller.dart';
import '../../staff/presentation/widgets/staff_picker.dart';
import '../domain/sushi_rice_batch.dart';
import 'sushi_rice_batch_controller.dart';

/// Routed at `/logs/sushiRice/new` — "New Preparation Rice Batch": choose
/// rice weight, run the Soaking checklist, and pick who's starting it, then
/// Save & Print. Soaking itself is a fixed 30-minute countdown (see
/// `sushiRiceSoakTotalMinutes`), not a chosen duration. The label prints
/// immediately here (batch creation), not after a later verification step.
class SushiRiceNewBatchScreen extends ConsumerStatefulWidget {
  const SushiRiceNewBatchScreen({super.key});

  @override
  ConsumerState<SushiRiceNewBatchScreen> createState() => _SushiRiceNewBatchScreenState();
}

class _SushiRiceNewBatchScreenState extends ConsumerState<SushiRiceNewBatchScreen> {
  int _step = 0;
  double _riceWeightLbs = 6;
  bool _ricePotSanitized = false;
  bool _riceInspectedWashed = false;
  bool _enzymeAdded = false;
  bool _riceWeightConfirmed = false;
  String? _staffId;
  String? _staffName;
  bool _saving = false;

  static const _weightOptions = [3.0, 6.0, 10.0];

  /// Shared sizing so every Back/Next/Continue/Save button across all
  /// three steps ends up the same height and width (via `Expanded`
  /// siblings sharing this style) instead of drifting per-step.
  ButtonStyle _stepButtonStyle(Color backgroundColor) => ElevatedButton.styleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(56),
    padding: const EdgeInsets.symmetric(vertical: 16),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  @override
  Widget build(BuildContext context) {
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
                  const Expanded(
                    child: Text(
                      'New Preparation Rice Batch',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    DateFormat('EEE MMM d, yyyy h:mma').format(DateTime.now()),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Sushi Rice Soaking',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 20),
                        switch (_step) {
                          0 => _buildWeightStep(),
                          1 => _buildChecklistStep(),
                          _ => _buildStaffStep(),
                        },
                      ],
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

  Widget _buildWeightStep() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/weight.png', width: 18, height: 18),
              const SizedBox(width: 8),
              const Text('Choose Rice Weight', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final weight in _weightOptions)
                _WeightOption(
                  weightLbs: weight,
                  selected: _riceWeightLbs == weight,
                  onTap: () => setState(() => _riceWeightLbs = weight),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: _stepButtonStyle(AppTheme.navyDark),
              onPressed: () => setState(() => _step = 1),
              child: const Text('NEXT →'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistStep() {
    final totalLbs = _riceWeightLbs + sushiRicePotWeightLbs;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please check the following steps are done',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _ChecklistRow(
            label: 'Rice Pot Sanitized',
            checked: _ricePotSanitized,
            onChanged: (value) => setState(() => _ricePotSanitized = value),
          ),
          const SizedBox(height: 10),
          _ChecklistRow(
            label: 'Rice Inspected & Washed',
            checked: _riceInspectedWashed,
            onChanged: (value) => setState(() => _riceInspectedWashed = value),
          ),
          const SizedBox(height: 10),
          _ChecklistRow(
            label: 'Checked Rice Weight Total ${totalLbs.toStringAsFixed(1)} Lbs',
            checked: _riceWeightConfirmed,
            onChanged: (value) => setState(() => _riceWeightConfirmed = value),
          ),
          const SizedBox(height: 10),
          _ChecklistRow(
            label: 'Enzyme Added (Optional)',
            checked: _enzymeAdded,
            onChanged: (value) => setState(() => _enzymeAdded = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: _stepButtonStyle(AppTheme.navyDark),
                  onPressed: () => setState(() => _step = 0),
                  child: const Text('← BACK'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: _stepButtonStyle(AppTheme.navyDark),
                  onPressed: _ricePotSanitized && _riceInspectedWashed && _riceWeightConfirmed
                      ? () => setState(() => _step = 2)
                      : null,
                  child: const Text('CONTINUE →'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffStep() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaffNamePicker(
            selectedId: _staffId,
            onChanged: (id) {
              final staff = ref.read(staffMembersProvider).valueOrNull ?? const [];
              setState(() {
                _staffId = id;
                _staffName = staff.where((s) => s.id == id).firstOrNull?.name;
              });
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Color(0xFF1971C2)),
                SizedBox(width: 8),
                Expanded(child: Text('Batch Number will be generated automatically.')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: _stepButtonStyle(AppTheme.navyDark),
                  onPressed: () => setState(() => _step = 1),
                  child: const Text('← BACK'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: _stepButtonStyle(AppTheme.success),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'SAVING...' : 'SAVE & PRINT'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_staffId == null || _staffName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter or select who is starting this batch.')));
      return;
    }
    if (!await hasNetworkConnection()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please check your internet connection.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await ref.read(sushiRiceBatchControllerProvider).startBatch(
            riceWeightLbs: _riceWeightLbs,
            ricePotSanitized: _ricePotSanitized,
            riceInspectedWashed: _riceInspectedWashed,
            enzymeAdded: _enzymeAdded,
            staffId: _staffId!,
            staffName: _staffName!,
          );
      if (!mounted) return;
      if (!result.alarmPermissionGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are disabled for this app, so this batch\'s buzzer alarms may '
              'not go off. Enable notifications in system settings.',
            ),
          ),
        );
      }
      if (!result.labelPrinted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.printError ?? 'Could not print the label.')),
        );
      }
      context.pushReplacement('/logs/sushiRice/batch/${result.batch.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// A full-width checklist row: label + a square checkbox icon on the
/// trailing edge, highlighting green (background/border/icon) once
/// checked. Every row here is a real toggle — [onChanged] is only ever
/// null for a row this screen deliberately wants to render disabled.
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.checked, required this.onChanged});

  final String label;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return InkWell(
      onTap: enabled ? () => onChanged!(!checked) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: checked ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: checked ? AppTheme.success : AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: enabled ? Colors.black87 : Colors.black54),
              ),
            ),
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 22,
              color: checked ? AppTheme.success : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightOption extends StatelessWidget {
  const _WeightOption({required this.weightLbs, required this.selected, required this.onTap});

  final double weightLbs;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totalLbs = weightLbs + sushiRicePotWeightLbs;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppTheme.success : AppTheme.border, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${weightLbs.toStringAsFixed(0)} Lbs',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Pot + Rice = ${totalLbs.toStringAsFixed(1)} Lbs',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
