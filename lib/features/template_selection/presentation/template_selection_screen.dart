import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../food_selection/presentation/food_selection_screen.dart';
import '../../label_printing/domain/food_rotation_label_data.dart';
import '../../label_printing/domain/label_data.dart';
import '../../label_printing/domain/label_template.dart';
import '../../label_printing/presentation/label_print_controller.dart';
import '../../printer_workspace/presentation/printer_workspace_screen.dart';
import 'template_selection_controller.dart';
import 'widgets/template_card.dart';

/// First step of the printing flow: pick which label template to use.
/// Picking one either goes straight to the print page, or through Food
/// Selection first — driven entirely by [LabelTemplate.requiresFoodSelection],
/// so adding a template never means adding another navigation branch here.
class TemplateSelectionScreen extends ConsumerStatefulWidget {
  const TemplateSelectionScreen({super.key});

  @override
  ConsumerState<TemplateSelectionScreen> createState() => _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends ConsumerState<TemplateSelectionScreen> {
  late LabelTemplateType _highlighted;

  @override
  void initState() {
    super.initState();
    _highlighted = ref.read(selectedLabelTemplateProvider);
  }

  /// Representative data for a template's live thumbnail preview — not the
  /// data used for actual printing, just a sample so the card shows what
  /// the template looks like.
  LabelData _sampleFor(LabelTemplateType type) {
    return switch (type) {
      LabelTemplateType.pokeBowlBurrito => PokeBowlLabelData.initial(),
      LabelTemplateType.foodRotation => FoodRotationLabelData.initial().copyWith(
          foodName: 'Imitation Crab Salad',
          employee: 'JS',
        ),
    };
  }

  void _continue() {
    final template = LabelTemplateCatalog.byType(_highlighted);
    ref.read(selectedLabelTemplateProvider.notifier).state = template.type;

    if (template.requiresFoodSelection) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FoodSelectionScreen()),
      );
    } else {
      ref.read(labelPrintControllerProvider.notifier).startNewLabel(template.type);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PrinterWorkspaceScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Choose Label Template',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        for (final template in LabelTemplateCatalog.all)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TemplateCard(
                              template: template,
                              sampleData: _sampleFor(template.type),
                              selected: _highlighted == template.type,
                              onTap: () => setState(() => _highlighted = template.type),
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _continue,
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
