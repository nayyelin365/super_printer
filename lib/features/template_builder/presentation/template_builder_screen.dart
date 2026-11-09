import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import 'template_builder_controller.dart';
import 'widgets/component_list.dart';
import 'widgets/component_palette.dart';
import 'widgets/component_property_editor.dart';
import 'widgets/interactive_label_canvas.dart';

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
        if (context.canPop()) context.pop();
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
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  Text(
                    state.isEditing ? 'Edit Template' : 'Create Template',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.pop(),
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
            'CANVAS SIZE (INCHES)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45),
          ),
          const SizedBox(height: 6),
          _CanvasSizeFields(state: state),
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
    final aspectRatio = state.template.widthInches / state.template.heightInches;

    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              'LABEL PREVIEW — drag to move, drag the corner handle to resize',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 16),
            // A tall/narrow custom canvas (e.g. 3 x 6 in) can be much taller
            // than this panel's available height at a 460px width — cap by
            // whichever dimension is actually the tighter constraint instead
            // of always sizing from a fixed width, so it stays fully visible
            // (and inside the SingleChildScrollView as a fallback) rather
            // than overflowing vertically.
            LayoutBuilder(
              builder: (context, constraints) {
                const maxWidth = 460.0;
                final maxHeight = MediaQuery.of(context).size.height * 0.6;
                var width = maxWidth;
                var height = width / aspectRatio;
                if (height > maxHeight) {
                  height = maxHeight;
                  width = height * aspectRatio;
                }
                return SizedBox(
                  width: width,
                  height: height,
                  child: InteractiveLabelCanvas(state: state),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Width/height (inches) inputs for the canvas itself — separate from a
/// component's own X/Y/Width/Height in [ComponentPropertyEditor]. Changing
/// these rescales every existing component proportionally (see
/// [TemplateBuilderController.setCanvasSize]) rather than clipping them.
class _CanvasSizeFields extends ConsumerWidget {
  const _CanvasSizeFields({required this.state});
  final TemplateBuilderState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(templateBuilderControllerProvider.notifier);

    return Row(
      children: [
        Expanded(
          child: TextFormField(
            key: ValueKey('canvas-width-${state.template.id}'),
            initialValue: state.template.widthInches.toStringAsFixed(1),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Width (in)', isDense: true),
            onChanged: (text) {
              final width = double.tryParse(text);
              if (width != null && width > 0) {
                controller.setCanvasSize(width, state.template.heightInches);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            key: ValueKey('canvas-height-${state.template.id}'),
            initialValue: state.template.heightInches.toStringAsFixed(1),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Height (in)', isDense: true),
            onChanged: (text) {
              final height = double.tryParse(text);
              if (height != null && height > 0) {
                controller.setCanvasSize(state.template.widthInches, height);
              }
            },
          ),
        ),
      ],
    );
  }
}
