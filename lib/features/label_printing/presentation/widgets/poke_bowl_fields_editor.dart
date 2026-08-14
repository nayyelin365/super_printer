import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/label_data.dart';
import '../label_print_controller.dart';

/// Editable fields for the "Custom Poke Bowl / Burrito" template, shown
/// under the live preview.
class PokeBowlFieldsEditor extends ConsumerWidget {
  const PokeBowlFieldsEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelPrintControllerProvider);
    final controller = ref.read(labelPrintControllerProvider.notifier);
    final data = state.labelData as PokeBowlLabelData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: ValueKey('name-${state.formGeneration}'),
          initialValue: data.productName,
          decoration: const InputDecoration(labelText: 'Product Name'),
          onChanged: controller.updateProductName,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('netwt-${state.formGeneration}'),
                initialValue: data.netWeight?.toString() ?? '',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Net Weight (lb)'),
                onChanged: controller.updateNetWeight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: ValueKey('price-${state.formGeneration}'),
                initialValue: data.pricePerLb?.toString() ?? '',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price / lb'),
                onChanged: controller.updatePricePerLb,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
