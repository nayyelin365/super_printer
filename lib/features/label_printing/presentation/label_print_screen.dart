import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/label_template.dart';
import 'label_print_controller.dart';
import 'widgets/custom_template_fields_editor.dart';
import 'widgets/edit_pricing_dialog.dart';
import 'widgets/food_rotation_fields_editor.dart';
import 'widgets/label_preview.dart';
import 'widgets/poke_bowl_fields_editor.dart';
import 'widgets/print_details_panel.dart';

class LabelPrintScreen extends StatelessWidget {
  const LabelPrintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final template = ref.watch(labelPrintControllerProvider).template;
            return Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(left: 8, right: 8),
                      child: Icon(Icons.print_outlined),
                    ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Menu Label Print',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (template == LabelTemplateType.pokeBowlBurrito)
                    IconButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const EditPricingDialog(),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit Pricing',
                    ),
                ],
              ),
            );
          },
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
                        Expanded(child: left),
                        const SizedBox(width: 20),
                        Expanded(child: right),
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
          switch (state.template) {
            LabelTemplateType.pokeBowlBurrito => const PokeBowlFieldsEditor(),
            LabelTemplateType.foodRotation => const FoodRotationFieldsEditor(),
            LabelTemplateType.custom => const CustomTemplateFieldsEditor(),
          },
        ],
      ),
    );
  }
}
