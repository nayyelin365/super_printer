import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/label_data.dart';
import '../label_print_controller.dart';

/// Editable fields for the "Custom Poke Bowl / Burrito" template, shown
/// under the live preview. Pricing itself (base price, extras, total) is
/// edited from the Print Details panel, not here.
class PokeBowlFieldsEditor extends ConsumerWidget {
  const PokeBowlFieldsEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelPrintControllerProvider);
    final controller = ref.read(labelPrintControllerProvider.notifier);
    final data = state.labelData as PokeBowlLabelData;

    return TextFormField(
      key: ValueKey('name-${state.formGeneration}'),
      initialValue: data.productName,
      decoration: const InputDecoration(labelText: 'Product Name'),
      onChanged: controller.updateProductName,
    );
  }
}
