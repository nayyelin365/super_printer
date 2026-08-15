import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../food_selection/presentation/food_selection_screen.dart';
import '../../label_printing/domain/custom_label_data.dart';
import '../../label_printing/domain/food_rotation_label_data.dart';
import '../../label_printing/domain/label_data.dart';
import '../../label_printing/domain/label_template.dart';
import '../../label_printing/presentation/label_print_controller.dart';
import '../../printer_workspace/presentation/printer_workspace_screen.dart';
import '../../template_builder/presentation/template_builder_controller.dart';
import '../../template_builder/presentation/template_builder_screen.dart';
import '../../template_builder/presentation/template_repository_controller.dart';
import 'template_selection_controller.dart';
import 'widgets/template_card.dart';

/// First step of the printing flow: pick which label template to use, or
/// create a new custom one. Picking one either goes straight to the print
/// page, or through Food Selection first — driven entirely by
/// [LabelTemplate.requiresFoodSelection], so adding a template (built-in or
/// custom) never means adding another navigation branch here.
class TemplateSelectionScreen extends ConsumerStatefulWidget {
  const TemplateSelectionScreen({super.key});

  @override
  ConsumerState<TemplateSelectionScreen> createState() => _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends ConsumerState<TemplateSelectionScreen> {
  late LabelTemplate _highlighted;

  @override
  void initState() {
    super.initState();
    _highlighted = ref.read(selectedLabelTemplateProvider);
  }

  /// Representative data for a template's live thumbnail preview — not the
  /// data used for actual printing, just a sample so the card shows what
  /// the template looks like.
  LabelData _sampleFor(LabelTemplate template) {
    return switch (template.type) {
      LabelTemplateType.pokeBowlBurrito => PokeBowlLabelData.initial(),
      LabelTemplateType.foodRotation => FoodRotationLabelData.initial().copyWith(
          foodName: 'Imitation Crab Salad',
          employee: 'JS',
        ),
      LabelTemplateType.custom => CustomLabelData.initial(template),
    };
  }

  void _continue() {
    final template = _highlighted;
    ref.read(selectedLabelTemplateProvider.notifier).state = template;

    if (template.requiresFoodSelection) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FoodSelectionScreen()),
      );
    } else {
      ref.read(labelPrintControllerProvider.notifier).startNewLabel(template);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PrinterWorkspaceScreen()),
      );
    }
  }

  void _createTemplate() {
    ref.read(editingTemplateProvider.notifier).state = null;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TemplateBuilderScreen()),
    );
  }

  void _editTemplate(LabelTemplate template) {
    ref.read(editingTemplateProvider.notifier).state = template;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TemplateBuilderScreen()),
    );
  }

  Future<void> _duplicateTemplate(LabelTemplate template) async {
    final copy = await ref.read(customTemplatesProvider.notifier).duplicateTemplate(template);
    setState(() => _highlighted = copy);
  }

  Future<void> _deleteTemplate(LabelTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Template?'),
          content: Text('Are you sure you want to delete "${template.name}"?'),
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
    if (confirmed != true) return;

    await ref.read(customTemplatesProvider.notifier).deleteTemplate(template.id);
    if (_highlighted.id == template.id) {
      setState(() => _highlighted = LabelTemplateCatalog.pokeBowlBurrito);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(allTemplatesProvider);
    // The highlighted template may have just been deleted/duplicated
    // elsewhere; keep it valid.
    if (!templates.any((t) => t.id == _highlighted.id)) {
      _highlighted = templates.first;
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _continue,
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Continue'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
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
                  const Expanded(
                    child: Text(
                      'Choose Label Template',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: _createTemplate,
                    icon: const Icon(Icons.add),
                    tooltip: 'Create Template',
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                // Extra bottom padding so the last card never sits under
                // the floating Continue button.
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        for (final template in templates)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TemplateCard(
                              template: template,
                              sampleData: _sampleFor(template),
                              selected: _highlighted.id == template.id,
                              onTap: () => setState(() => _highlighted = template),
                              onEdit: template.isBuiltIn ? null : () => _editTemplate(template),
                              onDuplicate:
                                  template.isBuiltIn ? null : () => _duplicateTemplate(template),
                              onDelete: template.isBuiltIn ? null : () => _deleteTemplate(template),
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
