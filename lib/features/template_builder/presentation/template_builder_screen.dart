import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../label_printing/domain/custom_label_data.dart';
import '../../label_printing/presentation/widgets/label_preview.dart';
import 'template_builder_controller.dart';
import 'widgets/component_list.dart';
import 'widgets/component_palette.dart';
import 'widgets/component_property_editor.dart';

/// Visual editor for a custom template: add/position components on the
/// left, see the exact same renderer used for printing on the right. Used
/// for both creating a new template and editing an existing one — see
/// [editingTemplateProvider].
class TemplateBuilderScreen extends ConsumerWidget {
  const TemplateBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(templateBuilderControllerProvider);
    final controller = ref.read(templateBuilderControllerProvider.notifier);

    ref.listen(templateBuilderControllerProvider, (previous, next) {
      if (next.saved && previous?.saved != true) {
        Navigator.of(context).pop();
      }
    });

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
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  Text(
                    state.isEditing ? 'Edit Template' : 'Create Template',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: state.isSaving ? null : controller.save,
                    child: Text(state.isSaving ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ),
            if (state.errorMessage != null)
              Container(
                width: double.infinity,
                color: AppTheme.danger.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final left = _ComponentsPanel(state: state);
                  final right = _PreviewPanel(state: state);

                  if (constraints.maxWidth >= 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 340, child: left),
                        const VerticalDivider(width: 1, color: AppTheme.border),
                        Expanded(child: right),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [right, const SizedBox(height: 20), left],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentsPanel extends ConsumerWidget {
  const _ComponentsPanel({required this.state});
  final TemplateBuilderState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(templateBuilderControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TEMPLATE NAME',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: state.template.name,
            decoration: const InputDecoration(hintText: 'e.g. My Kitchen Label'),
            onChanged: controller.setName,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Requires Food Selection', style: TextStyle(fontSize: 13)),
              ),
              Switch(
                value: state.template.requiresFoodSelection,
                onChanged: controller.setRequiresFoodSelection,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'COMPONENTS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45),
          ),
          const SizedBox(height: 10),
          const ComponentPalette(),
          const SizedBox(height: 14),
          const ComponentList(),
          const Divider(height: 32),
          const Text(
            'SELECTED COMPONENT',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45),
          ),
          const SizedBox(height: 10),
          const ComponentPropertyEditor(),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.state});
  final TemplateBuilderState state;

  @override
  Widget build(BuildContext context) {
    final previewData = CustomLabelData.initial(state.template);

    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          const Text(
            'LABEL PREVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: LabelPreview(data: previewData),
          ),
        ],
      ),
    );
  }
}
