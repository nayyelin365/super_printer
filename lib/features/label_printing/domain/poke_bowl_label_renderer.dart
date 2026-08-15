import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'label_data.dart';
import 'label_template_renderer.dart';

/// Renderer for the "Custom Poke Bowl / Burrito" template.
///
/// Sections below the header are laid out with a running vertical cursor
/// rather than fixed y-coordinates, so optional sections (currently just
/// the barcode) can be skipped entirely without leaving a gap: the whole
/// content block is then centered in the space below the header, keeping
/// the label visually balanced whether or not the barcode is shown.
class PokeBowlLabelRenderer extends LabelTemplateRenderer {
  const PokeBowlLabelRenderer();

  static const double designWidth = LabelCanvas.designWidth;
  static const double designHeight = LabelCanvas.designHeight;

  static const _headerHeight = 100.0;
  static const _nameSectionHeight = 100.0;
  static const _infoRowSectionHeight = 92.0;
  static const _datesSectionHeight = 82.0;

  // The barcode's own footprint (bars + its digit row, which the `barcode`
  // package draws inside this same height) plus a fixed trailing margin —
  // not "whatever's left of the label", so a bigger/smaller barcode never
  // leaves a mismatched gap below it. Any remaining slack is instead spent
  // as an even top/bottom margin around the whole content block (see
  // `_paintAtDesignScale`).
  static const _barcodeWidth = 380.0;
  static const _barcodeHeight = 170.0;
  static const _barcodeBottomMargin = 30.0;
  static const _barcodeSectionHeight = _barcodeHeight + _barcodeBottomMargin;

  static const _accentGray = Color(0xFF6B7280);
  static const _dividerColor = Color(0xFF706E6E);
  static const _borderColor = Color(0xFFDBDBDB);

  static final _dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

  @override
  void paint(Canvas canvas, Size outputSize, LabelData data) {
    final pokeBowl = data as PokeBowlLabelData;
    canvas.save();
    canvas.scale(
      outputSize.width / designWidth,
      outputSize.height / designHeight,
    );
    _paintAtDesignScale(canvas, pokeBowl);
    canvas.restore();
  }

  void _paintAtDesignScale(Canvas canvas, PokeBowlLabelData data) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, designWidth, designHeight),
      Paint()..color = Colors.white,
    );

    _paintHeader(canvas);

    final contentHeight = _nameSectionHeight +
        _infoRowSectionHeight +
        _datesSectionHeight +
        (data.showBarcode ? _barcodeSectionHeight : 0);
    final availableHeight = designHeight - _headerHeight;
    final extraSpace = availableHeight - contentHeight;
    var cursor = _headerHeight + (extraSpace > 0 ? extraSpace / 2 : 0);

    cursor = _paintProductName(canvas, data, cursor);
    cursor = _paintInfoRow(canvas, data, cursor);
    cursor = _paintDates(canvas, data, cursor);
    if (data.showBarcode) {
      _paintBarcode(canvas, data, cursor);
    }

    _paintOuterBorder(canvas);
  }

  /// A table-style border around the whole label, drawn last so it sits
  /// cleanly on top of the header/content beneath it.
  void _paintOuterBorder(Canvas canvas) {
    const strokeWidth = 3.0;
    canvas.drawRect(
      const Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        designWidth - strokeWidth,
        designHeight - strokeWidth,
      ),
      Paint()
        ..color = _borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  void _paintHeader(Canvas canvas) {
    _drawText(
      canvas,
      'FLAVORHUB',
      center: const Offset(designWidth / 2, _headerHeight / 2),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 45,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    );
  }

  /// Returns the cursor for the next section (this section's bottom edge).
  double _paintProductName(Canvas canvas, PokeBowlLabelData data, double top) {
    final name = data.productName.trim().isEmpty
        ? 'UNNAMED PRODUCT'
        : data.productName.toUpperCase();
    _drawText(
      canvas,
      name,
      center: Offset(designWidth / 2, top + 32),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 45,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: designWidth - 60,
    );

    final dividerY = top + _nameSectionHeight;
    canvas.drawLine(
      Offset(40, dividerY),
      Offset(designWidth - 40, dividerY),
      Paint()
        ..color = _dividerColor
        ..strokeWidth = 2,
    );

    return dividerY;
  }

  double _paintInfoRow(Canvas canvas, PokeBowlLabelData data, double top) {
    const labelStyle = TextStyle(
      color: _accentGray,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );
    const valueStyle = TextStyle(
      color: Colors.black,
      fontSize: 30,
      fontWeight: FontWeight.w700,
    );
    const totalValueStyle = TextStyle(
      color: Colors.black,
      fontSize: 35,
      fontWeight: FontWeight.w800,
    );

    final columns = [
      (
        label: 'NET WT',
        value: data.netWeight != null
            ? '${data.netWeight!.toStringAsFixed(2)} lb'
            : '-',
        style: valueStyle,
      ),
      (
        label: 'PRICE/LB',
        value: data.pricePerLb != null
            ? '\$${data.pricePerLb!.toStringAsFixed(2)}'
            : '-',
        style: valueStyle,
      ),
      (
        label: 'TOTAL',
        value: '\$${data.totalAmount.toStringAsFixed(2)}',
        style: totalValueStyle,
      ),
    ];

    final labelY = top + 26;
    final valueY = labelY + 34;
    final bottom = top + _infoRowSectionHeight;

    final columnWidth = (designWidth - 80) / 3;
    for (var i = 0; i < columns.length; i++) {
      final centerX = 40 + columnWidth * i + columnWidth / 2;
      final col = columns[i];
      _drawText(
        canvas,
        col.label,
        center: Offset(centerX, labelY),
        style: labelStyle,
      );
      _drawText(
        canvas,
        col.value,
        center: Offset(centerX, valueY),
        style: col.style,
      );
    }

    canvas.drawLine(
      Offset(40, bottom),
      Offset(designWidth - 40, bottom),
      Paint()
        ..color = _dividerColor
        ..strokeWidth = 2,
    );

    // Vertical dividers between columns, spanning the full row height
    // (matching the horizontal dividers above/below) so it reads as a table.
    for (var i = 1; i < columns.length; i++) {
      final x = 40 + columnWidth * i;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        Paint()
          ..color = _dividerColor
          ..strokeWidth = 2,
      );
    }

    return bottom;
  }

  double _paintDates(Canvas canvas, PokeBowlLabelData data, double top) {
    final textTop = top + 22;
    const labelStyle = TextStyle(
      color: Colors.black,
      fontSize: 26,
      fontWeight: FontWeight.w700,
    );

    final useByText = 'BEST BY: ${_dateFormat.format(data.useBy)}';
    final useByWidth = _measureText(useByText, labelStyle);

    // Space-between: PACKED pinned to the left margin, BEST BY pinned to
    // the right margin, with the gap between them flexing to fill the row.
    _drawText(
      canvas,
      'PACKED: ${_dateFormat.format(data.packedAt)}',
      left: 40,
      top: textTop,
      style: labelStyle,
    );
    _drawText(
      canvas,
      useByText,
      left: designWidth - 40 - useByWidth,
      top: textTop,
      style: labelStyle,
    );

    return top + _datesSectionHeight;
  }

  void _paintBarcode(Canvas canvas, PokeBowlLabelData data, double top) {
    const width = _barcodeWidth;
    const height = _barcodeHeight;
    // Right-aligned, but pulled in further than the usual 40px margin so
    // it doesn't sit flush against the edge.
    const rightMargin = 90.0;
    const left = designWidth - rightMargin - width;
    const fontHeight = 20.0;

    // 12-digit payload; the package computes and appends the 13th
    // (check) digit itself when rendering the bars.
    final payload = data.barcodeData;

    final barcode = Barcode.ean13();
    if (!barcode.isValid(payload)) return;

    // drawText: true is what gives a standard-looking EAN-13 — without it
    // the package skips the taller guard bars and the classic digit
    // placement (leading digit outside the left guard, two 6-digit groups,
    // checksum outside the right guard), producing uniform-height bars
    // with no numerals lined up under them.
    for (final element in barcode.make(
      payload,
      width: width,
      height: height,
      drawText: true,
      fontHeight: fontHeight,
    )) {
      switch (element) {
        case BarcodeBar(:final black) when black:
          canvas.drawRect(
            Rect.fromLTWH(
              left + element.left,
              top + element.top,
              element.width,
              element.height,
            ),
            Paint()..color = Colors.black,
          );
        case BarcodeText():
          _paintBarcodeText(canvas, element, left, top);
        default:
          break;
      }
    }
  }

  void _paintBarcodeText(Canvas canvas, BarcodeText element, double originX, double originY) {
    final textAlign = switch (element.align) {
      BarcodeTextAlign.left => TextAlign.left,
      BarcodeTextAlign.center => TextAlign.center,
      BarcodeTextAlign.right => TextAlign.right,
    };
    final painter = TextPainter(
      text: TextSpan(
        text: element.text,
        style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign,
    )..layout(minWidth: element.width, maxWidth: element.width);
    painter.paint(canvas, Offset(originX + element.left, originY + element.top));
  }

  /// Paints [text] and returns its rendered width, so callers can lay out
  /// adjacent text (e.g. a second label in the same row) after it.
  double _drawText(
    Canvas canvas,
    String text, {
    Offset? center,
    double? left,
    double? top,
    required TextStyle style,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      ellipsis: maxWidth != null ? '…' : null,
      maxLines: 1,
    );
    painter.layout(maxWidth: maxWidth ?? designWidth);

    final Offset origin;
    if (center != null) {
      origin = Offset(
        center.dx - painter.width / 2,
        center.dy - painter.height / 2,
      );
    } else {
      origin = Offset(left ?? 0, top ?? 0);
    }
    painter.paint(canvas, origin);
    return painter.width;
  }

  /// Measures [text] without painting it, so a caller can right-align (or
  /// otherwise position) it before drawing.
  double _measureText(String text, TextStyle style, {double? maxWidth}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth ?? designWidth);
    return painter.width;
  }
}
