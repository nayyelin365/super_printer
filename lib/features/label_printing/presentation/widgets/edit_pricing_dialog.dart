import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../poke_bowl_pricing_controller.dart';

/// Lets the seller rename/reprice any Base Price or Extra tile shown on the
/// Poke Bowl / Burrito print page — opened from the edit icon in
/// [LabelPrintScreen]'s app bar. Changes are only saved to
/// [pokeBowlPricingProvider] when Save is tapped.
class EditPricingDialog extends ConsumerStatefulWidget {
  const EditPricingDialog({super.key});

  @override
  ConsumerState<EditPricingDialog> createState() => _EditPricingDialogState();
}

class _EditPricingDialogState extends ConsumerState<EditPricingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameControllers = <String, TextEditingController>{};
  final _priceControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final pricing = ref.read(pokeBowlPricingProvider);
    for (final option in pricing.basePrices) {
      _nameControllers[option.id] = TextEditingController(text: option.label);
      _priceControllers[option.id] = TextEditingController(text: option.amount.toStringAsFixed(2));
    }
    for (final option in pricing.extras) {
      _nameControllers[option.id] = TextEditingController(text: option.label);
      _priceControllers[option.id] = TextEditingController(text: option.amount.toStringAsFixed(2));
    }
  }

  @override
  void dispose() {
    for (final c in _nameControllers.values) {
      c.dispose();
    }
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(pokeBowlPricingProvider.notifier);
    final pricing = ref.read(pokeBowlPricingProvider);

    for (final option in pricing.basePrices) {
      final label = _nameControllers[option.id]!.text.trim();
      final amount = double.tryParse(_priceControllers[option.id]!.text) ?? option.amount;
      if (label != option.label || amount != option.amount) {
        await controller.updateBasePrice(option.id, label: label, amount: amount);
      }
    }
    for (final option in pricing.extras) {
      final label = _nameControllers[option.id]!.text.trim();
      final amount = double.tryParse(_priceControllers[option.id]!.text) ?? option.amount;
      if (label != option.label || amount != option.amount) {
        await controller.updateExtraPrice(option.id, label: label, amount: amount);
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pricing = ref.watch(pokeBowlPricingProvider);

    return AlertDialog(
      title: const Text('Edit Pricing'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DialogSectionLabel('BASE PRICE'),
                for (final option in pricing.basePrices)
                  _PricingRow(
                    nameController: _nameControllers[option.id]!,
                    priceController: _priceControllers[option.id]!,
                  ),
                const SizedBox(height: 16),
                const _DialogSectionLabel('EXTRA'),
                for (final option in pricing.extras)
                  _PricingRow(
                    nameController: _nameControllers[option.id]!,
                    priceController: _priceControllers[option.id]!,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PricingRow extends StatelessWidget {
  const _PricingRow({required this.nameController, required this.priceController});

  final TextEditingController nameController;
  final TextEditingController priceController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(isDense: true, hintText: 'Name'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true, prefixText: '\$ '),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.black45,
        ),
      ),
    );
  }
}
