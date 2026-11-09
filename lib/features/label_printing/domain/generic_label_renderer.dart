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

  /// Design resolution custom templates are authored at — matches the
  /// fixed 300 DPI every other template's design grid assumes (see
  /// [LabelCanvas]), so a 3 x 2 in custom template still lands on the
  /// same 900 x 600 grid existing saved templates/components were built
  /// against. Unlike [LabelCanvas]'s fixed constants, a custom template's
  /// grid genuinely scales with its own [LabelTemplate.widthInches]/
  /// [LabelTemplate.heightInches] — see [TemplateBuilderController.setCanvasSize]
  /// for how component coordinates are kept consistent when that changes.
  static const int designDpi = 300;

  @override
  void paint(Canvas canvas, Size outputSize, LabelData data) {
    final custom = data as CustomLabelData;
    final designWidth = custom.template.widthInches * designDpi;
    final designHeight = custom.template.heightInches * designDpi;
    canvas.save();
    canvas.scale(
      outputSize.width / designWidth,
      outputSize.height / designHeight,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, designWidth, designHeight),
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
        case LabelComponentType.box:
          _paintBox(canvas, component);
        case LabelComponentType.image:
          // Not yet supported; reserved so the schema doesn't need to
          // change when image components are implemented.
          break;
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(1.5, 1.5, designWidth - 3, designHeight - 3),
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
          color: component.whiteText ? Colors.white : Colors.black,
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

  /// Matches the Sushi Template Label's barcode rendering: bars plus the
  /// human-readable number printed underneath (see
  /// `SushiTemplateLabelRenderer._paintBarcode`/`_paintBarcodeText`), rather
  /// than bars alone.
  void _paintBarcode(Canvas canvas, LabelComponent component, String value) {
    if (!component.barcodeSymbology.isValid(value)) return;
    final barcode = component.barcodeSymbology.codec;

    for (final element in barcode.make(
      value,
      width: component.width,
      height: component.height,
      drawText: true,
      fontHeight: component.fontSize,
    )) {
      switch (element) {
        case bc.BarcodeBar(:final black) when black:
          canvas.drawRect(
            Rect.fromLTWH(
              component.x + element.left,
              component.y + element.top,
              element.width,
              element.height,
            ),
            Paint()..color = Colors.black,
          );
        case bc.BarcodeText():
          _paintBarcodeText(canvas, component, element);
        default:
          break;
      }
    }
  }

  void _paintBarcodeText(Canvas canvas, LabelComponent component, bc.BarcodeText element) {
    final textAlign = switch (element.align) {
      bc.BarcodeTextAlign.left => TextAlign.left,
      bc.BarcodeTextAlign.center => TextAlign.center,
      bc.BarcodeTextAlign.right => TextAlign.right,
    };
    final painter = TextPainter(
      text: TextSpan(
        text: element.text,
        style: TextStyle(color: Colors.black, fontSize: component.fontSize, fontWeight: FontWeight.w600),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign,
    )..layout(minWidth: element.width, maxWidth: element.width);
    painter.paint(canvas, Offset(component.x + element.left, component.y + element.top));
  }

  void _paintDivider(Canvas canvas, LabelComponent component) {
    final end = component.vertical
        ? Offset(component.x, component.y + component.height)
        : Offset(component.x + component.width, component.y);
    canvas.drawLine(
      Offset(component.x, component.y),
      end,
      Paint()
        ..color = const Color(0xFF706E6E)
        ..strokeWidth = component.thickness,
    );
  }

  /// Matches the Sushi Template Label's boxed sections (see
  /// `SushiTemplateLabelRenderer._drawBoxedLines`): a solid black fill when
  /// [LabelComponent.filled], or a black border [LabelComponent.thickness]
  /// wide otherwise. Purely decorative — any text/barcode meant to sit
  /// inside it is a separate component positioned on top.
  void _paintBox(Canvas canvas, LabelComponent component) {
    final rect = Rect.fromLTWH(component.x, component.y, component.width, component.height);
    canvas.drawRect(
      rect,
      component.filled
          ? (Paint()..color = Colors.black)
          : (Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = component.thickness),
    );
  }
}
