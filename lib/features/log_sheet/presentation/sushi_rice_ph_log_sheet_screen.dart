import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/sushi_rice_batch.dart';
import 'sushi_rice_batch_controller.dart';

/// Routed at `/logs/sushiRice/report` (every batch, side by side — with a
/// search box to narrow that down to one) and `/logs/sushiRice/report/
/// :batchId` (opens straight to one batch's own column, reached by tapping
/// a batch card on the dashboard) — the "Sushi Rice pH Log Sheet": a
/// structured HACCP compliance record (Stage 1–4 sections, pH critical
/// limit, corrective action, holding/expiration, final status), one column
/// per batch, sourced directly from [SushiRiceBatch] rather than the
/// generic Log Sheet table — this is the actual audit record the SOP
/// needs, not a summary row.
class SushiRicePhLogSheetScreen extends ConsumerStatefulWidget {
  const SushiRicePhLogSheetScreen({super.key, this.batchId});

  /// When set, the search box starts pre-filled with this batch's code —
  /// how a batch card's "View Log Sheet" link opens straight to its own
  /// record while still leaving the box editable to switch batches.
  final String? batchId;

  @override
  ConsumerState<SushiRicePhLogSheetScreen> createState() => _SushiRicePhLogSheetScreenState();
}

class _SushiRicePhLogSheetScreenState extends ConsumerState<SushiRicePhLogSheetScreen> {
  late final TextEditingController _searchController;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(allSushiRiceBatchesProvider);

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
                  const Text(
                    'Sushi Rice pH Log Sheet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: batchesAsync.when(
                data: (allBatches) {
                  // The pending-search version of the deep-linked batch's
                  // code — set once, before the user's typed anything, so
                  // opening from a batch card lands pre-filtered to it
                  // without locking the box against picking a different one.
                  if (_searchController.text.isEmpty && widget.batchId != null) {
                    final linked = allBatches.where((b) => b.id == widget.batchId).firstOrNull;
                    if (linked != null) {
                      _search = linked.batchCode;
                      _searchController.text = linked.batchCode;
                    }
                  }

                  if (allBatches.isEmpty) {
                    return const Center(
                      child: Text(
                        'No batches recorded yet.',
                        style: TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                    );
                  }

                  final query = _search.trim().toLowerCase();
                  final batches = query.isEmpty
                      ? allBatches
                      : allBatches.where((b) => b.batchCode.toLowerCase().contains(query)).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() => _search = value),
                            decoration: InputDecoration(
                              hintText: 'Enter Batch... (leave blank for all)',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _search.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => setState(() {
                                        _search = '';
                                        _searchController.clear();
                                      }),
                                    ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: batches.isEmpty
                            ? Center(
                                child: Text(
                                  'No batch matches "$_search".',
                                  style: const TextStyle(color: Colors.black45, fontSize: 14),
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: _LogSheetTable(batches: batches),
                              ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// (label, value-getter) rows grouped under one blue section banner.
class _Section {
  const _Section(this.title, this.rows, {this.badge});
  final String title;
  final String? badge;
  final List<(String, String Function(SushiRiceBatch))> rows;
}

const _dateFmt = 'd MMM yyyy';
const _timeFmt = 'h:mm a';

String _fmtDate(DateTime? d) => d == null ? '' : DateFormat(_dateFmt).format(d);
String _fmtTime(DateTime? d) => d == null ? '' : DateFormat(_timeFmt).format(d);

final _sections = <_Section>[
  _Section('Stage 1: Preparation', [
    ('Rice Washing & Soaking Started', (b) => _fmtTime(b.soakStartedAt)),
    ('Staff', (b) => b.staffName ?? ''),
    ('Rice Cooking Started', (b) => _fmtTime(b.cookRestStartedAt)),
    ('Rice Cooking Finished', (b) => _fmtTime(b.mixCoolStartedAt)),
  ]),
  _Section(
    'Stage 2: HACCP Control - pH',
    [
      ('Vinegar Mixing Time', (b) => _fmtTime(b.mixCoolStartedAt)),
      ('pH Reading Time', (b) => _fmtTime(b.phReadingAt)),
      ('pH Value', (b) => b.phReading?.toStringAsFixed(1) ?? ''),
      ('Result', (b) => b.phReading == null ? '' : (b.phPassed ? 'PASS' : 'FAIL')),
      ('pH Meter Name & Calibrated Date', (b) => ''),
      ('Staff', (b) => b.phCheckStaffName ?? ''),
    ],
    badge: 'Critical Limit: ≤ ${sushiRicePhPassThreshold.toStringAsFixed(1)}',
  ),
  _Section('Corrective Action', [
    ('Corrective Action Taken', (b) => b.correctiveActionTaken ? 'YES' : 'N/A'),
    ('Corrective Action Taken Time', (b) => _fmtTime(b.correctiveActionTakenAt)),
    ('Corrective pH Value', (b) => b.correctivePhValue?.toStringAsFixed(1) ?? ''),
    ('Staff', (b) => b.correctiveActionTaken ? (b.phCheckStaffName ?? '') : ''),
  ]),
  _Section('Stage 3: Holding & Lifecycle', [
    ('Ready for Use Time', (b) => _fmtTime(b.readyToUseStartedAt)),
    (
      'Holding Time Limit',
      (b) => b.readyToUseStartedAt == null ? '' : '$sushiRiceReadyToUseWindowHours hr',
    ),
    ('Calculated Expiration Time', (b) {
      final deadline = b.readyToUseDeadline;
      return deadline == null ? '' : '${_fmtDate(deadline)} ${_fmtTime(deadline)}';
    }),
  ]),
  _Section('Stage 4: End of Batch Record', [
    ('Final Batch Status', (b) => b.finalBatchStatus ?? ''),
    ('Time of Final Status', (b) => _fmtTime(b.finishedAt)),
    ('Staff', (b) => b.finalStatusStaffName ?? ''),
  ]),
];

class _LogSheetTable extends StatelessWidget {
  const _LogSheetTable({required this.batches});

  final List<SushiRiceBatch> batches;

  static const _labelColumnWidth = 260.0;
  static const _batchColumnWidth = 160.0;
  static const _rowHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(
              label: 'Date',
              values: [for (final b in batches) _fmtDate(b.soakStartedAt)],
              header: true,
            ),
            _row(
              label: 'Batch No.',
              values: [for (final b in batches) b.batchCode],
              header: true,
            ),
            for (final section in _sections) ...[
              _sectionBanner(section),
              for (final row in section.rows)
                _row(label: row.$1, values: [for (final b in batches) row.$2(b)]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionBanner(_Section section) {
    return Container(
      width: _labelColumnWidth + batches.length * _batchColumnWidth,
      height: _rowHeight,
      color: const Color(0xFFBEE3F8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            section.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          if (section.badge != null) ...[
            const SizedBox(width: 12),
            Text(
              section.badge!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row({required String label, required List<String> values, bool header = false}) {
    return Container(
      height: _rowHeight,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: _labelColumnWidth,
            height: _rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppTheme.border)),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: header ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          for (final value in values)
            Container(
              width: _batchColumnWidth,
              height: _rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppTheme.border)),
              ),
              child: Text(value, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
