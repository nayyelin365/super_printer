import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../food_selection/presentation/food_selection_controller.dart';
import '../domain/log_entry.dart';
import '../domain/log_type.dart';
import 'export/log_sheet_excel.dart';
import 'export/log_sheet_pdf.dart';
import 'log_controller.dart';
import 'widgets/log_entry_table.dart';

/// Routed at `/logs/:logType` — the table for one [LogType], with search,
/// date/food/location filtering, and Add/Print/Export actions.
class LogSheetScreen extends ConsumerStatefulWidget {
  const LogSheetScreen({super.key, required this.logType});

  final LogType logType;

  @override
  ConsumerState<LogSheetScreen> createState() => _LogSheetScreenState();
}

class _LogSheetScreenState extends ConsumerState<LogSheetScreen> {
  String _search = '';
  DateTime? _dateFilter;
  String? _foodFilter;
  String? _locationFilter;

  List<LogEntry> _applyFilters(List<LogEntry> entries) {
    final query = _search.trim().toLowerCase();
    return entries.where((entry) {
      if (query.isNotEmpty &&
          !entry.foodName.toLowerCase().contains(query) &&
          !entry.locationName.toLowerCase().contains(query) &&
          !entry.initials.toLowerCase().contains(query)) {
        return false;
      }
      if (_dateFilter != null &&
          !(entry.date.year == _dateFilter!.year &&
              entry.date.month == _dateFilter!.month &&
              entry.date.day == _dateFilter!.day)) {
        return false;
      }
      if (_foodFilter != null && entry.foodName != _foodFilter) return false;
      if (_locationFilter != null && entry.locationName != _locationFilter) return false;
      return true;
    }).toList();
  }

  String get _filterSummary {
    final parts = <String>[];
    if (_dateFilter != null) {
      parts.add(
        'Date: ${_dateFilter!.month.toString().padLeft(2, '0')}/'
        '${_dateFilter!.day.toString().padLeft(2, '0')}/${_dateFilter!.year}',
      );
    }
    if (_foodFilter != null) parts.add('Food: $_foodFilter');
    if (_locationFilter != null) parts.add('Location: $_locationFilter');
    if (_search.trim().isNotEmpty) parts.add('Search: "${_search.trim()}"');
    return parts.join(' · ');
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateFilter = picked);
  }

  void _openEntry(LogEntry? entry) {
    ref.read(editingLogEntryProvider.notifier).state = entry;
    context.push('/logs/${widget.logType.id}/entry');
  }

  Future<void> _confirmDelete(LogEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Log Entry?'),
          content: Text(
            'Delete the ${entry.dateLabel} ${entry.timeLabel} entry for "${entry.foodName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref.read(logControllerProvider).deleteEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(logEntriesProvider(widget.logType));
    // The full catalog, not `filteredFoodsProvider` — that shares its
    // search-query state with the Food Selection screen's own search box,
    // which would make typing there also filter this dropdown's options.
    final foods = ref.watch(foodCatalogProvider);
    final locations = ref.watch(logLocationsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/logs'),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.logType.label,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => entriesAsync.whenData(
                      (entries) => printLogSheetPdf(
                        logType: widget.logType,
                        entries: _applyFilters(entries),
                        filterSummary: _filterSummary,
                      ),
                    ),
                    icon: const Icon(Icons.print_outlined),
                    tooltip: 'Print / Export PDF',
                  ),
                  IconButton(
                    onPressed: () => entriesAsync.whenData(
                      (entries) => shareLogSheetExcel(
                        logType: widget.logType,
                        entries: _applyFilters(entries),
                      ),
                    ),
                    icon: const Icon(Icons.grid_on_outlined),
                    tooltip: 'Export Excel',
                  ),
                  IconButton(
                    onPressed: () => _openEntry(null),
                    icon: const Icon(Icons.add),
                    tooltip: 'Add entry',
                  ),
                  // Sushi Rice is the only log type with a guided SOP
                  // (Soaking -> Cook & Rest -> Cool & Acidify -> pH Check
                  // -> Ready to Use) — every other type only ever needs the
                  // plain add-entry form above.
                  if (widget.logType == LogType.sushiRice) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/logs/sushiRice/dashboard'),
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: const Text('Sushi Rice Preparation'),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: InputDecoration(
                        hintText: 'Search food, location, initials...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.event, size: 16),
                    label: Text(
                      _dateFilter == null
                          ? 'Any date'
                          : '${_dateFilter!.month.toString().padLeft(2, '0')}/'
                                '${_dateFilter!.day.toString().padLeft(2, '0')}/'
                                '${_dateFilter!.year}',
                    ),
                    onPressed: _pickDate,
                  ),
                  if (_dateFilter != null)
                    IconButton(
                      onPressed: () => setState(() => _dateFilter = null),
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Clear date filter',
                      visualDensity: VisualDensity.compact,
                    ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _foodFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(hintText: 'Food', isDense: true),
                      items: [
                        const DropdownMenuItem(
                          child: Text('All foods', overflow: TextOverflow.ellipsis),
                        ),
                        for (final food in foods)
                          DropdownMenuItem(
                            value: food.name,
                            child: Text(food.name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) => setState(() => _foodFilter = value),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      initialValue: _locationFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Unit Name / Location',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          child: Text('All locations', overflow: TextOverflow.ellipsis),
                        ),
                        for (final location in locations)
                          DropdownMenuItem(
                            value: location.name,
                            child: Text(location.name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) => setState(() => _locationFilter = value),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entriesAsync.when(
                data: (entries) {
                  final filtered = _applyFilters(entries);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        entries.isEmpty
                            ? 'No entries yet. Tap + to add one.'
                            : 'No entries match the current filters.',
                        style: const TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LogEntryTable(
                      entries: filtered,
                      onEdit: _openEntry,
                      onDelete: _confirmDelete,
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Could not load $_logTypeLabelLower entries.\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String get _logTypeLabelLower => widget.logType.label.toLowerCase();
}
