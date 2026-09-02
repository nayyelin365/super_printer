import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/network_error.dart';
import '../../food_selection/presentation/food_selection_controller.dart';
import '../../staff/presentation/staff_controller.dart';
import '../../staff/presentation/widgets/staff_picker.dart';
import '../domain/sushi_rice_batch.dart';
import 'log_controller.dart';
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
  String _soakingMethod = sushiRiceSoakingMethods.first;
  String? _staffId;
  String? _staffName;
  String? _foodName;
  String? _locationId;
  String? _locationName;
  bool _saving = false;

  static const _weightOptions = [3.0, 6.0, 10.0];

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
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Rice Pot Sanitized'),
            value: _ricePotSanitized,
            onChanged: (value) => setState(() => _ricePotSanitized = value ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Rice Inspected & Washed'),
            value: _riceInspectedWashed,
            onChanged: (value) => setState(() => _riceInspectedWashed = value ?? false),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline, color: Colors.black38),
            title: Text('Checked Rice Weight Total ${totalLbs.toStringAsFixed(1)} Lbs'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Enzyme Added (Optional)'),
            value: _enzymeAdded,
            onChanged: (value) => setState(() => _enzymeAdded = value ?? false),
          ),
          const SizedBox(height: 12),
          const Text('Soaking Method', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final method in sushiRiceSoakingMethods)
                ChoiceChip(
                  label: Text(method),
                  selected: _soakingMethod == method,
                  onSelected: (_) => setState(() => _soakingMethod = method),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 0),
                  child: const Text('← BACK'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _ricePotSanitized && _riceInspectedWashed
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
    final foods = ref.watch(foodCatalogProvider);
    final locationsAsync = ref.watch(logLocationsProvider);

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
          const Text('Food', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _foodName,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'Select the sushi rice item'),
            items: [
              for (final food in foods)
                DropdownMenuItem(
                  value: food.name,
                  child: Text(food.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _foodName = value),
          ),
          const SizedBox(height: 16),
          const Text('Unit Name / Location', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
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
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Text(
              'Could not load locations.',
              style: TextStyle(color: AppTheme.danger, fontSize: 12),
            ),
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
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text('← BACK'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
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
    if (_foodName == null || _locationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a food and a location.')));
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
            soakingMethod: _soakingMethod,
            staffId: _staffId!,
            staffName: _staffName!,
            foodName: _foodName!,
            locationId: _locationId!,
            locationName: _locationName!,
          );
      if (!mounted) return;
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
