import 'dart:ui' as ui;

import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'label_data.dart';
import 'label_template_renderer.dart';
import 'sushi_barcode.dart';
import 'sushi_template_label_data.dart';

/// Renderer for the "Sushi Template Label" built-in template (3 x 6 in).
///
/// Flat white background, black text throughout, laid out with a running
/// vertical cursor (see [PokeBowlLabelRenderer] for why) so the roll/
/// topping descriptions can wrap to as many lines as they need without
/// anything below them overlapping. The barcode is anchored to the bottom
/// of the label, centered.
class SushiTemplateLabelRenderer extends LabelTemplateRenderer {
  const SushiTemplateLabelRenderer();

  // 300 DPI design grid for a 3 x 6 inch label — same per-inch scale as
  // the other built-in templates' 900 x 600 grid (3 x 2 in), just taller.
  static const double designWidth = 900;
  static const double designHeight = 1800;

  static const _margin = 36.0;
  static const _boxWidth = 480.0;
  static const _boxPadding = 16.0;
  static const _barcodeHeight = 180.0;
  static const _barcodeWidth = 560.0;

  static final _dateFormat = DateFormat('MM/dd/yyyy');

  double get _contentLeft => _margin;
  double get _contentRight => designWidth - _margin;
  double get _contentWidth => designWidth - 2 * _margin;
  double get _centerX => designWidth / 2;

  @override
  void paint(Canvas canvas, Size outputSize, LabelData data) {
    final sushi = data as SushiTemplateLabelData;
    canvas.save();
    canvas.scale(
      outputSize.width / designWidth,
      outputSize.height / designHeight,
    );
    _paintAtDesignScale(canvas, sushi);
    canvas.restore();
  }

  void _paintAtDesignScale(Canvas canvas, SushiTemplateLabelData data) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, designWidth, designHeight),
      Paint()..color = Colors.white,
    );

    var cursor = _margin;
    cursor = _drawText(
      canvas,
      SushiTemplateLabelData.madeFreshDailyText,
      centerX: _centerX,
      top: cursor,
      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 22),
    );
    cursor += 6;
    cursor = _drawText(
      canvas,
      data.productTitle.toUpperCase(),
      centerX: _centerX,
      top: cursor,
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 42),
      maxWidth: _contentWidth,
    );
    cursor += 16;

    canvas.drawLine(
      Offset(_contentLeft, cursor),
      Offset(_contentRight, cursor),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 2,
    );
    cursor += 20;

    cursor = _paintBadgeRow(canvas, data, cursor);
    cursor += 26;

    // Sell Through and Price side by side in one row — each box is laid
    // out independently (they can end up different heights), so the
    // cursor after the row is whichever box's bottom edge is lower.
    const rowGap = 24.0;
    final rowBoxWidth = (_contentWidth - rowGap) / 2;
    final sellThroughCenterX = _contentLeft + rowBoxWidth / 2;
    final priceCenterX = _contentRight - rowBoxWidth / 2;

    final sellThroughBottom = _drawBoxedLines(
      canvas,
      top: cursor,
      width: rowBoxWidth,
      centerX: sellThroughCenterX,
      lines: [
        (data.bestIfUseByLabel, const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 24)),
        (
          _dateFormat.format(data.bestIfUseByAt),
          const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 20)
        ),
      ],
    );
    final priceBottom = _drawBoxedLines(
      canvas,
      top: cursor,
      width: rowBoxWidth,
      centerX: priceCenterX,
      fillColor: Colors.black,
      lines: [
        (
          '\$${data.price.toStringAsFixed(2)}',
          const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 40)
        ),
      ],
    );
    cursor = (sellThroughBottom > priceBottom ? sellThroughBottom : priceBottom) + 30;

    // Same font size as the product title (food name), per request.
    const descriptionStyle =
        TextStyle(color: Colors.black,  fontSize: 36);
    cursor = _drawWrapped(canvas, data.rollDescription, cursor, style: descriptionStyle);
    cursor += 18;
    cursor = _drawWrapped(canvas, data.topDescription, cursor, style: descriptionStyle);
    cursor += 26;

    cursor = _drawBoxedLines(
      canvas,
      top: cursor,
      width: _contentWidth,
      lines: [
        (
          SushiTemplateLabelData.perishableText,
          const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 24)
        ),
      ],
    );
    cursor += 10;
    _drawText(
      canvas,
      SushiTemplateLabelData.eatSameDayText,
      centerX: _centerX,
      top: cursor,
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 22),
    );

    _paintBarcode(canvas, data);
  }

  /// "READY TO EAT" and "FULLY COOKED" as bordered badges, with the net
  /// weight right-aligned on the same row.
  double _paintBadgeRow(Canvas canvas, SushiTemplateLabelData data, double top) {
    const style = TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 22);
    const padding = 12.0;

    final readyWidth = _measureWidth(SushiTemplateLabelData.readyToEatText, style);
    final cookedWidth = _measureWidth(data.fullyCookedText.toUpperCase(), style);
    final rowHeight = style.fontSize! + padding * 2 + 6;

    _drawBadge(
      canvas,
      SushiTemplateLabelData.readyToEatText,
      left: _contentLeft,
      top: top,
      style: style,
      padding: padding,
      measuredWidth: readyWidth,
    );
    _drawBadge(
      canvas,
      data.fullyCookedText.toUpperCase(),
      left: _centerX - (cookedWidth + padding * 2) / 2,
      top: top,
      style: style,
      padding: padding,
      measuredWidth: cookedWidth,
    );

    final netWeightStyle =
        const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 24);
    final netWeightWidth = _measureWidth(data.netWeightText, netWeightStyle);
    _drawText(
      canvas,
      data.netWeightText,
      left: _contentRight - netWeightWidth,
      top: top + (rowHeight - netWeightStyle.fontSize!) / 2 - 4,
      style: netWeightStyle,
    );

    return top + rowHeight;
  }

  void _drawBadge(
    Canvas canvas,
    String text, {
    required double left,
    required double top,
    required TextStyle style,
    required double padding,
    required double measuredWidth,
  }) {
    final boxWidth = measuredWidth + padding * 2;
    final boxHeight = style.fontSize! + padding * 2;
    canvas.drawRect(
      Rect.fromLTWH(left, top, boxWidth, boxHeight),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawText(canvas, text, left: left + padding, top: top + padding - 2, style: style);
  }

  /// Draws a bordered (or [fillColor]-filled) box, [width] wide (default
  /// [_boxWidth]) and horizontally centered, containing [lines] stacked
  /// and center-aligned. Every line is measured (laid out) before
  /// anything is painted, so the box's background is always drawn first
  /// and the text second — painting content before the background would
  /// otherwise hide it under a filled box.
  double _drawBoxedLines(
    Canvas canvas, {
    required double top,
    required List<(String text, TextStyle style)> lines,
    double width = _boxWidth,
    double? centerX,
    Color? fillColor,
    double lineGap = 2,
  }) {
    final left = (centerX ?? _centerX) - width / 2;
    final innerWidth = width - 2 * _boxPadding;

    final painters = [
      for (final (text, style) in lines)
        TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: innerWidth),
    ];
    final contentHeight =
        painters.fold(0.0, (sum, p) => sum + p.height) + lineGap * (painters.length - 1);
    final boxHeight = contentHeight + 2 * _boxPadding;
    final rect = Rect.fromLTWH(left, top, width, boxHeight);

    canvas.drawRect(
      rect,
      fillColor != null
          ? (Paint()..color = fillColor)
          : (Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2),
    );

    var y = top + _boxPadding;
    for (final painter in painters) {
      painter.paint(canvas, Offset(left + (width - painter.width) / 2, y));
      y += painter.height + lineGap;
    }

    return top + boxHeight;
  }

  /// The selected barcode type, centered horizontally and anchored to the
  /// bottom margin of the label.
  void _paintBarcode(Canvas canvas, SushiTemplateLabelData data) {
    final barcode = data.barcodeType.codec;
    if (data.barcodeValue.isEmpty || !barcode.isValid(data.barcodeValue)) return;

    final left = (designWidth - _barcodeWidth) / 2;
    final top = designHeight - _margin - _barcodeHeight;

    for (final element in barcode.make(
      data.barcodeValue,
      width: _barcodeWidth,
      height: _barcodeHeight,
      drawText: true,
      fontHeight: 18,
    )) {
      switch (element) {
        case bc.BarcodeBar(:final black) when black:
          canvas.drawRect(
            Rect.fromLTWH(
              left + element.left,
              top + element.top,
              element.width,
              element.height,
            ),
            Paint()..color = Colors.black,
          );
        case bc.BarcodeText():
          _paintBarcodeText(canvas, element, left, top);
        default:
          break;
      }
    }
  }

  void _paintBarcodeText(Canvas canvas, bc.BarcodeText element, double originX, double originY) {
    final textAlign = switch (element.align) {
      bc.BarcodeTextAlign.left => TextAlign.left,
      bc.BarcodeTextAlign.center => TextAlign.center,
      bc.BarcodeTextAlign.right => TextAlign.right,
    };
    final painter = TextPainter(
      text: TextSpan(
        text: element.text,
        style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign,
    )..layout(minWidth: element.width, maxWidth: element.width);
    painter.paint(canvas, Offset(originX + element.left, originY + element.top));
  }

  /// Draws [text] wrapped across as many lines as it needs within the
  /// content width, returning the cursor position (bottom edge) after it.
  double _drawWrapped(
    Canvas canvas,
    String text,
    double top, {
    TextStyle style = const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 20),
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: _contentWidth);
    painter.paint(canvas, Offset(_contentLeft, top));
    return top + painter.height;
  }

  double _measureWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// Paints [text] and returns the cursor position (bottom edge) after it
  /// — callers chain straight off the return value. Exactly one of [left]
  /// / [centerX] should be given.
  double _drawText(
    Canvas canvas,
    String text, {
    double? left,
    double? centerX,
    required double top,
    required TextStyle style,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: centerX != null ? TextAlign.center : TextAlign.left,
      ellipsis: maxWidth != null ? '…' : null,
      maxLines: 1,
    );
    painter.layout(maxWidth: maxWidth ?? designWidth);

    final origin = centerX != null
        ? Offset(centerX - painter.width / 2, top)
        : Offset(left ?? 0, top);
    painter.paint(canvas, origin);
    return top + painter.height;
  }
}
