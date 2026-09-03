import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/sushi_rice_batch.dart';
import 'sushi_rice_batch_controller.dart';

/// Routed at `/logs/sushiRice/dashboard` — the "Sushi Rice Preparation"
/// dashboard: five stage cards plus a live list of every batch currently
/// moving through the SOP. Only Soaking is fully built right now (per the
/// staged rollout); the other four cards are shown for the overall shape
/// but tapping them just filters the batch list — they don't yet have
/// their own setup flow.
class SushiRiceDashboardScreen extends ConsumerStatefulWidget {
  const SushiRiceDashboardScreen({super.key});

  @override
  ConsumerState<SushiRiceDashboardScreen> createState() => _SushiRiceDashboardScreenState();
}

class _SushiRiceDashboardScreenState extends ConsumerState<SushiRiceDashboardScreen> {
  SushiRiceStage? _stageFilter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(activeSushiRiceBatchesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Kitchen Operations',
                style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.canPop() ? context.pop() : context.go('/logs'),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Sushi Rice Preparation',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/logs/sushiRice/report'),
                    icon: const Icon(Icons.soup_kitchen_outlined, size: 18),
                    label: const Text('Sushi Rice pH Log Sheet'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: batchesAsync.when(
                data: (batches) => _buildBody(batches),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<SushiRiceBatch> batches) {
    final counts = <SushiRiceStage, int>{};
    for (final batch in batches) {
      counts[batch.stage] = (counts[batch.stage] ?? 0) + 1;
    }

    final filtered = batches.where((b) {
      if (_stageFilter != null && b.stage != _stageFilter) return false;
      if (_search.trim().isNotEmpty &&
          !b.batchCode.toLowerCase().contains(_search.trim().toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final stage in SushiRiceStage.values)
                  _StageCard(
                    stage: stage,
                    index: SushiRiceStage.values.indexOf(stage) + 1,
                    waitingBatches: counts[stage] ?? 0,
                    selected: _stageFilter == stage,
                    onTap: () {
                      if (stage == SushiRiceStage.soaking) {
                        context.push('/logs/sushiRice/new');
                      } else {
                        setState(() => _stageFilter = _stageFilter == stage ? null : stage);
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    hintText: 'Enter Batch...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'QR scanning isn\'t available yet — use the search box above.',
                      ),
                    ),
                  ),
                  icon: SvgPicture.asset('assets/images/qr.svg', width: 18, height: 18),
                  label: const Text('Scan QR on Label'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No batches in progress.',
                            style: TextStyle(color: Colors.black45, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _BatchCard(batch: filtered[index]),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.index,
    required this.waitingBatches,
    required this.selected,
    required this.onTap,
  });

  final SushiRiceStage stage;
  final int index;
  final int waitingBatches;
  final bool selected;
  final VoidCallback onTap;

  static const _colors = {
    SushiRiceStage.soaking: Color(0xFFDCEEFB),
    SushiRiceStage.cookingRest: Color(0xFFFCEBD8),
    SushiRiceStage.mixingCooling: Color(0xFFDCF6F0),
    SushiRiceStage.phCheck: Color(0xFFE9E3FB),
    SushiRiceStage.readyToUse: Color(0xFFE0F8E4),
  };

  static const _assets = {
    SushiRiceStage.soaking: 'assets/images/socking.svg',
    SushiRiceStage.cookingRest: 'assets/images/cooking.svg',
    SushiRiceStage.mixingCooling: 'assets/images/vinegar.svg',
    SushiRiceStage.phCheck: 'assets/images/ph_level.svg',
    SushiRiceStage.readyToUse: 'assets/images/ready_sushi.svg',
  };

  static const _labels = {
    SushiRiceStage.soaking: 'Sushi Rice Soaking',
    SushiRiceStage.cookingRest: 'Cooking & Rest',
    SushiRiceStage.mixingCooling: 'Vinegar Mixing & Cooling',
    SushiRiceStage.phCheck: 'Measure pH Level',
    SushiRiceStage.readyToUse: 'Ready to Use',
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _colors[stage],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: AppTheme.navyDark, width: 2) : null,
          ),
          child: Stack(
            children: [
              if (stage != SushiRiceStage.soaking)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Wait-batches: $waitingBatches',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SvgPicture.asset(_assets[stage]!, width: 32, height: 32),
                  const SizedBox(height: 8),
                  Text(
                    '$index. ${_labels[stage]}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch});

  final SushiRiceBatch batch;

  static const _stageLabels = {
    SushiRiceStage.soaking: 'Soaking',
    SushiRiceStage.cookingRest: 'Cooking & Rest',
    SushiRiceStage.mixingCooling: 'Mixing & Cooling',
    SushiRiceStage.phCheck: 'pH Check',
    SushiRiceStage.readyToUse: 'Ready to Use',
  };

  /// This stage's own countdown deadline, per [SushiRiceStage] — pH Check
  /// has no timer of its own (staff acts as soon as they're ready), and
  /// Ready to Use tracks the 24-hr TPHC window instead of a short buzzer.
  DateTime? get _stageEndsAt => switch (batch.stage) {
    SushiRiceStage.soaking => batch.soakEndsAt,
    SushiRiceStage.cookingRest => batch.cookRestEndsAt,
    SushiRiceStage.mixingCooling => batch.mixCoolEndsAt,
    SushiRiceStage.phCheck => null,
    SushiRiceStage.readyToUse => batch.readyToUseDeadline,
  };

  @override
  Widget build(BuildContext context) {
    final remaining = _stageEndsAt?.difference(DateTime.now());
    final needsAction = remaining != null && remaining <= Duration.zero;
    final stageLabel = _stageLabels[batch.stage] ?? batch.stage.name;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: needsAction ? const Color(0xFFFDEDED) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: needsAction ? AppTheme.danger : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                needsAction ? Icons.notifications_active : Icons.water_drop,
                size: 18,
                color: needsAction ? AppTheme.danger : AppTheme.navyDark,
              ),
              const SizedBox(width: 8),
              Text(
                batch.batchCode,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              IconButton(
                onPressed: () => _copyBatchCode(context, batch.batchCode),
                icon: const Icon(Icons.copy, size: 14),
                tooltip: 'Copy batch number',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
              const Spacer(),
              if (remaining != null)
                Text(
                  _formatRemaining(remaining),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: needsAction ? AppTheme.danger : Colors.black54,
                  ),
                ),
              IconButton(
                onPressed: () => context.push('/logs/sushiRice/report/${batch.id}'),
                icon: const Icon(Icons.description_outlined, size: 18),
                tooltip: 'View Log Sheet',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            stageLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: needsAction ? AppTheme.danger : AppTheme.navyDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            needsAction
                ? 'Sushi Rice $stageLabel time has finished. Please proceed to the next step.'
                : 'Sushi rice $stageLabel in progress. Please wait until the time finishes.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: needsAction
                ? ElevatedButton(
                    onPressed: () => context.push('/logs/sushiRice/batch/${batch.id}'),
                    child: const Text('Take Action'),
                  )
                : OutlinedButton(
                    onPressed: () => context.push('/logs/sushiRice/batch/${batch.id}'),
                    child: const Text('View Details'),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(Duration remaining) {
    if (remaining <= Duration.zero) return '00:00';
    final hours = remaining.inHours;
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _copyBatchCode(BuildContext context, String batchCode) async {
    await Clipboard.setData(ClipboardData(text: batchCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied "$batchCode"'), duration: const Duration(seconds: 2)),
    );
  }
}
