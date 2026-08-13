import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import 'label_print_controller.dart';
import 'widgets/label_preview.dart';
import 'widgets/print_details_panel.dart';

class LabelPrintScreen extends StatelessWidget {
  const LabelPrintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: const Row(
            children: [
              Icon(Icons.print_outlined),
              SizedBox(width: 10),
              Text('Menu Label Print', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                const left = _PreviewColumn();
                const right = PrintDetailsPanel();

                if (isWide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: left),
                        const SizedBox(width: 20),
                        SizedBox(width: 360, child: right),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    left,
                    const SizedBox(height: 20),
                    right,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewColumn extends ConsumerWidget {
  const _PreviewColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelPrintControllerProvider);
    final controller = ref.read(labelPrintControllerProvider.notifier);
    final data = state.labelData;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LABEL PREVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.black45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: LabelPreview(data: data),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Label Fields',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
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
      ),
    );
  }
}
