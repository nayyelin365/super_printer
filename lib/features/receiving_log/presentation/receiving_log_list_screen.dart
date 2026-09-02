import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/network_error.dart';
import '../data/receiving_log_excel.dart';
import '../domain/receiving_invoice.dart';
import '../domain/receiving_item.dart';
import 'receiving_log_controller.dart';

/// Routed at `/receiving-log` — invoices as parent records with their
/// items nested underneath. "Receiving Log" shows everything; "Instock"
/// filters to only in-stock items (invoices with none are hidden).
class ReceivingLogListScreen extends ConsumerStatefulWidget {
  const ReceivingLogListScreen({super.key});

  @override
  ConsumerState<ReceivingLogListScreen> createState() => _ReceivingLogListScreenState();
}

class _ReceivingLogListScreenState extends ConsumerState<ReceivingLogListScreen> {
  bool _inStockOnly = false;
  String _search = '';
  DateTime? _dateFilter;

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(receivingInvoicesWithItemsProvider);

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
                    onPressed: () => context.canPop() ? context.pop() : context.go('/templates'),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Receiving Log & Instock',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => invoicesAsync.whenData(
                      (invoices) => shareReceivingLogExcel(invoices: _applyFilters(invoices)),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Export'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/receiving-log/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Log'),
                  ),
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
                  _FilterChip(
                    label: 'Receiving Log',
                    selected: !_inStockOnly,
                    onTap: () => setState(() => _inStockOnly = false),
                  ),
                  _FilterChip(
                    label: 'Instock',
                    selected: _inStockOnly,
                    onTap: () => setState(() => _inStockOnly = true),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: InputDecoration(
                        hintText: 'Search Item/Invoice No',
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
                          ? 'Received Date'
                          : DateFormat('MM/dd/yyyy').format(_dateFilter!),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dateFilter ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _dateFilter = picked);
                    },
                  ),
                  if (_dateFilter != null)
                    IconButton(
                      onPressed: () => setState(() => _dateFilter = null),
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Clear date filter',
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            Expanded(
              child: invoicesAsync.when(
                data: (invoices) {
                  final filtered = _applyFilters(invoices);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        invoices.isEmpty
                            ? 'No receiving logs yet. Tap "+ Add Log" to add one.'
                            : 'No entries match the current filters.',
                        style: const TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) =>
                        _InvoiceCard(invoice: filtered[index], inStockOnly: _inStockOnly),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Could not load receiving logs.\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ReceivingInvoice> _applyFilters(List<ReceivingInvoice> invoices) {
    final query = _search.trim().toLowerCase();
    return invoices.where((invoice) {
      if (_dateFilter != null &&
          !(invoice.receivedAt.year == _dateFilter!.year &&
              invoice.receivedAt.month == _dateFilter!.month &&
              invoice.receivedAt.day == _dateFilter!.day)) {
        return false;
      }
      if (_inStockOnly && !invoice.items.any((i) => i.status == ReceivingItemStatus.inStock)) {
        return false;
      }
      if (query.isEmpty) return true;
      if (invoice.invoiceNo.toLowerCase().contains(query)) return true;
      return invoice.items.any((i) => i.itemName.toLowerCase().contains(query));
    }).toList();
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.success.withValues(alpha: 0.25),
      onSelected: (_) => onTap(),
    );
  }
}

class _InvoiceCard extends ConsumerWidget {
  const _InvoiceCard({required this.invoice, required this.inStockOnly});

  final ReceivingInvoice invoice;
  final bool inStockOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = inStockOnly
        ? invoice.items.where((i) => i.status == ReceivingItemStatus.inStock).toList()
        : invoice.items;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _LabelValue('INVOICE', invoice.invoiceNo),
                const SizedBox(width: 24),
                _LabelValue('SUPPLIER', invoice.supplierName),
                const SizedBox(width: 24),
                _LabelValue(
                  'RECEIVED',
                  '${DateFormat('M.d.yyyy').format(invoice.receivedAt)} • '
                      '${DateFormat('h:mma').format(invoice.receivedAt)}',
                ),
                const SizedBox(width: 24),
                _LabelValue('BY', invoice.staffName ?? '-'),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push('/receiving-log/invoice/${invoice.id}/new-item'),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  tooltip: 'Add Receiving Item',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text('Items (${items.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (var i = 0; i < items.length; i++)
            _ItemRow(index: i + 1, item: items[i]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.index, required this.item});

  final int index;
  final ReceivingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (dateLabel, dateValue) = switch (item.status) {
      ReceivingItemStatus.inStock => ('Expired Date', item.vendorExpiryDate),
      ReceivingItemStatus.finished => ('Finished Date', item.finishedAt),
      ReceivingItemStatus.discarded => ('Discarded Date', item.discardedAt),
    };
    final statusColor = switch (item.status) {
      ReceivingItemStatus.inStock => AppTheme.success,
      ReceivingItemStatus.finished => Colors.black45,
      ReceivingItemStatus.discarded => AppTheme.danger,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${index.toString().padLeft(2, '0')}.',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'Batch: ${item.batchCode}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              item.temperatureF == null ? '-' : '${item.temperatureF!.toStringAsFixed(0)}°F',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: dateValue == null
                ? const Text('-', style: TextStyle(fontSize: 13))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateLabel, style: const TextStyle(fontSize: 10, color: Colors.black45)),
                      Text(DateFormat('M.d.yyyy').format(dateValue), style: const TextStyle(fontSize: 13)),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.status.label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
          if (item.status == ReceivingItemStatus.inStock) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _discard(context, ref),
              icon: const Icon(Icons.close, size: 18, color: AppTheme.danger),
              tooltip: 'Discard',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () => _finish(context, ref),
              icon: const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.success),
              tooltip: 'Finish',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    if (!await hasNetworkConnection()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please check your internet connection.')),
        );
      }
      return;
    }
    try {
      await ref.read(receivingLogControllerProvider).finishItem(item);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
      }
    }
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Discard Item?'),
          content: Text('Discard "${item.itemName}" (${item.batchCode})? This can\'t be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!await hasNetworkConnection()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please check your internet connection.')),
        );
      }
      return;
    }
    try {
      await ref.read(receivingLogControllerProvider).discardItem(item);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
      }
    }
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
