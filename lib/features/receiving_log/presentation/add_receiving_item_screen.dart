import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/network_error.dart';
import '../../food_selection/presentation/food_selection_controller.dart';
import '../../label_printing/domain/label_template.dart';
import '../../label_printing/presentation/label_print_controller.dart';
import '../../log_sheet/presentation/log_controller.dart';
import '../domain/receiving_invoice.dart';
import 'receiving_log_controller.dart';

const _units = ['lbs', 'kg', 'oz', 'pcs'];

/// Routed at `/receiving-log/invoice/:invoiceId/new-item` — "Add Receiving
/// Item": shows the parent invoice's read-only info, then the item form.
/// "Save & Print" saves the item and reuses the existing Food Rotation
/// label/print pipeline (the same one the interactive print screen uses)
/// rather than a new renderer — a printer failure doesn't block the save.
class AddReceivingItemScreen extends ConsumerStatefulWidget {
  const AddReceivingItemScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<AddReceivingItemScreen> createState() => _AddReceivingItemScreenState();
}

class _AddReceivingItemScreenState extends ConsumerState<AddReceivingItemScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _itemName;
  String _quantityText = '';
  String _unit = _units.first;
  String _temperatureText = '';
  DateTime? _vendorExpiryDate;
  String? _storageLocationId;
  String? _storageLocationName;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(receivingInvoicesProvider);
    final foods = ref.watch(foodCatalogProvider);
    final locationsAsync = ref.watch(logLocationsProvider);

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
                      'Add Receiving Item',
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
              child: invoicesAsync.when(
                data: (invoices) {
                  final invoice =
                      invoices.where((i) => i.id == widget.invoiceId).firstOrNull;
                  if (invoice == null) {
                    return const Center(child: Text('This invoice no longer exists.'));
                  }
                  return _buildForm(invoice, foods, locationsAsync);
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

  Widget _buildForm(ReceivingInvoice invoice, List foods, AsyncValue locationsAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: Colors.black54),
                          SizedBox(width: 6),
                          Text('Vendor Information', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        invoice.supplierName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _LabelValue('Invoice No.', invoice.invoiceNo),
                          ),
                          Expanded(
                            child: _LabelValue(
                              'Received Date/Time',
                              DateFormat('d.M.yyyy / h:mma').format(invoice.receivedAt),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Item Details', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      const Text('Item Name', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _itemName,
                        isExpanded: true,
                        decoration: const InputDecoration(hintText: 'Select an item'),
                        items: [
                          for (final food in foods)
                            DropdownMenuItem(
                              value: food.name,
                              child: Text(food.name, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (value) => setState(() => _itemName = value),
                        validator: (value) => value == null ? 'Select an item' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Total Weight / Quantity',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: '0'),
                              onChanged: (value) => _quantityText = value,
                              validator: (value) => (value == null || double.tryParse(value) == null)
                                  ? 'Enter a valid number'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _unit,
                            items: [
                              for (final unit in _units) DropdownMenuItem(value: unit, child: Text(unit)),
                            ],
                            onChanged: (value) => setState(() => _unit = value ?? _unit),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Temperature', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 6),
                      TextFormField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: '0', suffixText: '°F'),
                        onChanged: (value) => _temperatureText = value,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Vendor Expiry Date',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _vendorExpiryDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _vendorExpiryDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            hintText: 'Input Date',
                            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                          ),
                          child: Text(
                            _vendorExpiryDate == null
                                ? ''
                                : DateFormat('MMM d, yyyy').format(_vendorExpiryDate!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Storage Location',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      locationsAsync.when(
                        data: (locations) => DropdownButtonFormField<String>(
                          initialValue: _storageLocationId,
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
                              _storageLocationId = location.id;
                              _storageLocationName = location.name;
                            });
                          },
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) => const Text(
                          'Could not load locations.',
                          style: TextStyle(color: AppTheme.danger, fontSize: 12),
                        ),
                      ),
                    ],
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
                      Expanded(child: Text('Receiving Batch Number will be generated automatically.')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        child: const Text('← BACK'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                        onPressed: _saving ? null : () => _save(invoice),
                        child: Text(_saving ? 'SAVING...' : 'SAVE & PRINT'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(ReceivingInvoice invoice) async {
    if (!_formKey.currentState!.validate()) return;
    if (_storageLocationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a storage location.')));
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
      await ref.read(receivingLogControllerProvider).addItem(
            invoiceId: invoice.id,
            itemName: _itemName!,
            quantity: double.parse(_quantityText),
            unit: _unit,
            temperatureF: double.tryParse(_temperatureText),
            vendorExpiryDate: _vendorExpiryDate,
            storageLocationId: _storageLocationId,
            storageLocationName: _storageLocationName,
          );

      // Reuse the existing Food Rotation label/print pipeline — the same
      // one the interactive print screen uses — rather than a new
      // renderer. A print failure doesn't block the save, matching the
      // Sushi Rice batch label's behavior.
      final printController = ref.read(labelPrintControllerProvider.notifier);
      printController.startNewLabel(LabelTemplateCatalog.foodRotation, foodName: _itemName);
      printController.updateEmployee(invoice.staffName ?? '');
      if (_vendorExpiryDate != null) {
        printController.updatePrepDateTime(DateTime.now());
      }
      await printController.print();
      final printState = ref.read(labelPrintControllerProvider);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Success'),
            content: Text(
              printState.errorMessage == null
                  ? 'Receiving item saved successfully!'
                  : 'Receiving item saved. ${printState.errorMessage}',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.pop();
                },
                child: const Text('Back to Receiving Log'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  setState(() {
                    _itemName = null;
                    _quantityText = '';
                    _temperatureText = '';
                    _vendorExpiryDate = null;
                    _storageLocationId = null;
                    _storageLocationName = null;
                    _formKey.currentState?.reset();
                  });
                },
                child: const Text('Add More'),
              ),
            ],
          );
        },
      );
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

class _LabelValue extends StatelessWidget {
  const _LabelValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
