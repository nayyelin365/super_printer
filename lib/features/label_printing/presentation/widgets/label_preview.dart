import 'package:flutter/material.dart';

import '../../domain/label_data.dart';
import '../../domain/label_template_renderer.dart';

/// Live preview of the label, built from the same renderer (looked up via
/// [LabelTemplateRenderers]) used to generate the print bitmap — never a
/// static image, and never a template-specific widget: adding a template
/// only means adding it to the registry.
class LabelPreview extends StatelessWidget {
  const LabelPreview({super.key, required this.data});

  final LabelData data;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: LabelCanvas.designWidth / LabelCanvas.designHeight,
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
          child: CustomPaint(
            painter: _LabelPainter(data),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _LabelPainter extends CustomPainter {
  _LabelPainter(this.data);

  final LabelData data;

  @override
  void paint(Canvas canvas, Size size) {
    LabelTemplateRenderers.forData(data).paint(canvas, size, data);
  }

  @override
  bool shouldRepaint(covariant _LabelPainter oldDelegate) => oldDelegate.data != data;
}
