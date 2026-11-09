import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../label_printing/domain/custom_label_data.dart';
import '../../../label_printing/domain/label_component.dart';
import '../../../label_printing/domain/label_data.dart';
import '../../../label_printing/domain/label_template_renderer.dart';
import '../template_builder_controller.dart';

/// Interactive version of the builder's live preview: drag a component
/// anywhere on the canvas to move it, or drag its corner handle to resize
/// it — the same [TemplateBuilderController.updateComponentById] call the
/// numeric X/Y/Width/Height fields in `ComponentPropertyEditor` use, so
/// both paths always agree and the preview never has to be re-painted
/// separately from what gets printed.
class InteractiveLabelCanvas extends ConsumerWidget {
  const InteractiveLabelCanvas({super.key, required this.state});

  final TemplateBuilderState state;

  static const double _minSize = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(templateBuilderControllerProvider.notifier);
    final template = state.template;
    final designWidth = template.widthInches * GenericDesign.dpi;
    final designHeight = template.heightInches * GenericDesign.dpi;
    final previewData = CustomLabelData.initial(template);

    return AspectRatio(
      aspectRatio: designWidth / designHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = constraints.maxWidth / designWidth;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _StaticPainter(previewData)),
                  ),
                  for (final component in template.components)
                    if (component.visible)
                      _ComponentOverlay(
                        key: ValueKey(component.id),
                        component: component,
                        scale: scale,
                        designWidth: designWidth,
                        designHeight: designHeight,
                        selected: component.id == state.selectedComponentId,
                        onSelect: () => controller.selectComponent(component.id),
                        onMove: (dx, dy) => controller.updateComponentById(component.id, (c) {
                          final maxX = designWidth - _visualWidth(c);
                          final maxY = designHeight - _visualHeightOf(c);
                          return c.copyWith(
                            x: (c.x + dx / scale).clamp(0.0, maxX < 0 ? 0.0 : maxX),
                            y: (c.y + dy / scale).clamp(0.0, maxY < 0 ? 0.0 : maxY),
                          );
                        }),
                        onResize: (dw, dh) => controller.updateComponentById(component.id, (c) {
                          if (c.type == LabelComponentType.divider) {
                            if (c.vertical) {
                              final maxHeight = designHeight - c.y;
                              final newHeight = (c.height + dh / scale).clamp(_minSize, maxHeight);
                              final newThickness = (c.thickness + dw / scale).clamp(1.0, 40.0);
                              return c.copyWith(height: newHeight, thickness: newThickness);
                            }
                            final maxWidth = designWidth - c.x;
                            final newWidth = (c.width + dw / scale).clamp(_minSize, maxWidth);
                            final newThickness = (c.thickness + dh / scale).clamp(1.0, 40.0);
                            return c.copyWith(width: newWidth, thickness: newThickness);
                          }
                          final maxWidth = designWidth - c.x;
                          final maxHeight = designHeight - c.y;
                          final newWidth = (c.width + dw / scale).clamp(_minSize, maxWidth);
                          final newHeight = (c.height + dh / scale).clamp(_minSize, maxHeight);
                          return c.copyWith(width: newWidth, height: newHeight);
                        }),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ComponentOverlay extends StatelessWidget {
  const _ComponentOverlay({
    super.key,
    required this.component,
    required this.scale,
    required this.designWidth,
    required this.designHeight,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onResize,
  });

  final LabelComponent component;
  final double scale;
  final double designWidth;
  final double designHeight;
  final bool selected;
  final VoidCallback onSelect;
  final void Function(double dx, double dy) onMove;
  final void Function(double dw, double dh) onResize;

  @override
  Widget build(BuildContext context) {
    final left = component.x * scale;
    final top = component.y * scale;
    final width = _visualWidth(component) * scale;
    final height = _visualHeightOf(component) * scale;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => onSelect(),
        onPanUpdate: (details) => onMove(details.delta.dx, details.delta.dy),
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  border: Border.all(color: Colors.blueAccent, width: 1.5),
                )
              : null,
          child: selected
              ? Align(
                  alignment: Alignment.bottomRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => onSelect(),
                    onPanUpdate: (details) => onResize(details.delta.dx, details.delta.dy),
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// A divider's drag/resize hit box in design units: a horizontal divider's
/// "length" is its [LabelComponent.width] (hit box height is its
/// [LabelComponent.thickness]); a vertical one's length is its
/// [LabelComponent.height] (hit box width is its thickness) — the two axes
/// are swapped from how every other component type uses width/height.
double _visualWidth(LabelComponent c) {
  if (c.type != LabelComponentType.divider) return c.width;
  return c.vertical ? (c.thickness < 16 ? 16 : c.thickness) : c.width;
}

double _visualHeightOf(LabelComponent c) {
  if (c.type != LabelComponentType.divider) return c.height;
  return c.vertical ? c.height : (c.thickness < 16 ? 16 : c.thickness);
}

class _StaticPainter extends CustomPainter {
  _StaticPainter(this.data);

  final LabelData data;

  @override
  void paint(Canvas canvas, Size size) {
    LabelTemplateRenderers.forData(data).paint(canvas, size, data);
  }

  @override
  bool shouldRepaint(covariant _StaticPainter oldDelegate) => oldDelegate.data != data;
}

/// Mirrors [GenericLabelRenderer.designDpi] — kept as its own tiny constant
/// here so this widget only needs the one `label_template_renderer.dart`
/// import for [LabelTemplateRenderers], not the generic renderer itself.
class GenericDesign {
  const GenericDesign._();
  static const double dpi = 300;
}
