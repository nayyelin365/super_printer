import 'dart:ui' as ui;

import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';

import 'custom_label_data.dart';
import 'label_component.dart';
import 'label_data.dart';
import 'label_template_renderer.dart';

/// Renders any custom (user-created) template by looping over its
/// [LabelComponent]s — the same method drives the template builder's live
/// preview, the print page's preview, and the final print bitmap, so a
/// template can never look different printed than it did while being built.
class GenericLabelRenderer extends LabelTemplateRenderer {
  const GenericLabelRenderer();

  static const double designWidth = LabelCanvas.designWidth;
  static const double designHeight = LabelCanvas.designHeight;

  @override
  void paint(Canvas canvas, Size outputSize, LabelData data) {
    final custom = data as CustomLabelData;
    canvas.save();
    canvas.scale(
      outputSize.width / designWidth,
      outputSize.height / designHeight,
    );

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, designWidth, designHeight),
      Paint()..color = Colors.white,
    );

    for (final component in custom.template.components) {
      if (!component.visible) continue;
      switch (component.type) {
        case LabelComponentType.text:
          _paintText(canvas, component, custom.resolve(component));
        case LabelComponentType.dateTime:
          _paintText(canvas, component, custom.resolve(component));
        case LabelComponentType.barcode:
          _paintBarcode(canvas, component, custom.resolve(component));
        case LabelComponentType.divider:
          _paintDivider(canvas, component);
        case LabelComponentType.image:
          // Not yet supported; reserved so the schema doesn't need to
          // change when image components are implemented.
          break;
      }
    }

    canvas.drawRect(
      const Rect.fromLTWH(1.5, 1.5, designWidth - 3, designHeight - 3),
      Paint()
        ..color = const Color(0xFFDBDBDB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    canvas.restore();
  }

  void _paintText(Canvas canvas, LabelComponent component, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: component.fontSize,
          fontWeight: component.bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: component.alignment,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: component.width);

    double dx = component.x;
    if (component.alignment == TextAlign.center) {
      dx = component.x + (component.width - painter.width) / 2;
    } else if (component.alignment == TextAlign.right) {
      dx = component.x + component.width - painter.width;
    }
    painter.paint(canvas, Offset(dx, component.y));
  }

  void _paintBarcode(Canvas canvas, LabelComponent component, String value) {
    if (value.trim().isEmpty) return;
    final barcode = bc.Barcode.code128();
    if (!barcode.isValid(value)) return;

    for (final element in barcode.make(
      value,
      width: component.width,
      height: component.height,
      drawText: false,
    )) {
      if (element is bc.BarcodeBar && element.black) {
        canvas.drawRect(
          Rect.fromLTWH(
            component.x + element.left,
            component.y + element.top,
            element.width,
            element.height,
          ),
          Paint()..color = Colors.black,
        );
      }
    }
  }

  void _paintDivider(Canvas canvas, LabelComponent component) {
    canvas.drawLine(
      Offset(component.x, component.y),
      Offset(component.x + component.width, component.y),
      Paint()
        ..color = const Color(0xFF706E6E)
        ..strokeWidth = component.thickness,
    );
  }
}
