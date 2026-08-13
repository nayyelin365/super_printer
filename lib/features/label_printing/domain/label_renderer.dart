import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'label_data.dart';

/// Draws a 3 x 2 inch label from [LabelData].
///
/// This is the single source of truth for label layout: the live preview
/// widget and the final print bitmap both call [paint], so what the user
/// sees is exactly what gets printed. Layout is authored in a fixed
/// "design space" of [designWidth] x [designHeight] (the 300 DPI pixel
/// grid) and scaled with [Canvas.scale] to whatever concrete output size
/// is requested — a small preview, or the full-resolution print target.
class LabelRenderer {
  const LabelRenderer();

  static const double designWidth = 900;
  static const double designHeight = 600;

  // Info row (NET WT / PRICE/LB / TOTAL) top/bottom bounds — shared by the
  // horizontal dividers above/below the row and the vertical dividers
  // between its columns, so they always line up as one table.
  static const _infoRowTop = 152.0;
  static const _infoRowBottom = 238.0;

  static const _headerColor = Color(0xFF10202E);
  static const _accentGray = ui.Color.fromARGB(255, 50, 51, 53);
  static const _dividerColor = ui.Color.fromARGB(255, 112, 110, 110);
  static const _borderColor = ui.Color.fromARGB(255, 219, 219, 219);

  static final _dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

  /// Paints the label into [canvas], scaled to fill [outputSize].
  void paint(Canvas canvas, Size outputSize, LabelData data) {
    canvas.save();
    canvas.scale(
      outputSize.width / designWidth,
      outputSize.height / designHeight,
    );
    _paintAtDesignScale(canvas, data);
    canvas.restore();
  }

  void _paintAtDesignScale(Canvas canvas, LabelData data) {
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, designWidth, designHeight),
      bg,
    );

    _paintHeader(canvas);
    _paintProductName(canvas, data);
    _paintInfoRow(canvas, data);
    _paintDates(canvas, data);
    _paintBarcode(canvas, data);
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
    const headerHeight = 100.0;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, designWidth, headerHeight),
      Paint()..color = _headerColor,
    );
    _drawText(
      canvas,
      'FLAVORHUB',
      center: const Offset(designWidth / 2, headerHeight / 2),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 38,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    );
  }

  void _paintProductName(Canvas canvas, LabelData data) {
    final name = data.productName.trim().isEmpty
        ? 'UNNAMED PRODUCT'
        : data.productName.toUpperCase();
    _drawText(
      canvas,
      name,
      center: const Offset(designWidth / 2, 126),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 34,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: designWidth - 60,
    );
    canvas.drawLine(
      const Offset(40, _infoRowTop),
      const Offset(designWidth - 40, _infoRowTop),
      Paint()
        ..color = _dividerColor
        ..strokeWidth = 2,
    );
  }

  void _paintInfoRow(Canvas canvas, LabelData data) {
    const top = 180.0;
    const labelStyle = TextStyle(
      color: ui.Color.fromARGB(255, 31, 31, 31),
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
      fontSize: 32,
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

    final columnWidth = (designWidth - 80) / 3;
    for (var i = 0; i < columns.length; i++) {
      final centerX = 40 + columnWidth * i + columnWidth / 2;
      final col = columns[i];
      _drawText(
        canvas,
        col.label,
        center: Offset(centerX, top),
        style: labelStyle,
      );
      _drawText(
        canvas,
        col.value,
        center: Offset(centerX, top + 32),
        style: col.style,
      );
    }

    canvas.drawLine(
      const Offset(40, _infoRowBottom),
      const Offset(designWidth - 40, _infoRowBottom),
      Paint()
        ..color = _dividerColor
        ..strokeWidth = 2,
    );

    // Vertical dividers between columns, spanning the full row height
    // (matching the horizontal dividers above/below) so it reads as a table.
    for (var i = 1; i < columns.length; i++) {
      final x = 40 + columnWidth * i;
      canvas.drawLine(
        Offset(x, _infoRowTop),
        Offset(x, _infoRowBottom),
        Paint()
          ..color = _dividerColor
          ..strokeWidth = 2,
      );
    }
  }

  void _paintDates(Canvas canvas, LabelData data) {
    const top = 260.0;
    const labelStyle = TextStyle(
      color: Colors.black,
      fontSize: 26,
      fontWeight: FontWeight.w700,
    );

    final useByText = 'USE BY: ${_dateFormat.format(data.useBy)}';
    final useByWidth = _measureText(useByText, labelStyle);

    // Space-between: PACKED pinned to the left margin, USE BY pinned to
    // the right margin, with the gap between them flexing to fill the row.
    _drawText(
      canvas,
      'PACKED: ${_dateFormat.format(data.packedAt)}',
      left: 40,
      top: top,
      style: labelStyle,
    );
    _drawText(
      canvas,
      useByText,
      left: designWidth - 40 - useByWidth,
      top: top,
      style: labelStyle,
    );
  }

  void _paintBarcode(Canvas canvas, LabelData data) {
    const left = 60.0;
    const top = 320.0;
    const width = designWidth - 120;
    const height = 190.0;

    // 12-digit payload; the package computes and appends the 13th
    // (check) digit itself when rendering the bars.
    final payload = data.barcodeData;

    final barcode = Barcode.ean13();
    if (!barcode.isValid(payload)) return;

    for (final element in barcode.make(
      payload,
      width: width,
      height: height,
      drawText: false,
    )) {
      if (element is BarcodeBar && element.black) {
        canvas.drawRect(
          Rect.fromLTWH(
            left + element.left,
            top + element.top,
            element.width,
            element.height,
          ),
          Paint()..color = Colors.black,
        );
      }
    }

    _drawText(
      canvas,
      data.barcodeDisplay,
      center: Offset(designWidth / 2, top + height + 20),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: 3,
      ),
    );
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

  /// Renders the label at the exact printer resolution and returns a
  /// row-major grayscale buffer (one byte per pixel, 0 = black, 255 =
  /// white), ready for [ZplEncoder.buildLabelZpl]. This is generated
  /// independently of the on-screen preview widget so the print output is
  /// never an upscaled screenshot.
  Future<Uint8List> renderToGrayscale({
    required LabelData data,
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    paint(canvas, Size(width.toDouble(), height.toDouble()), data);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    if (byteData == null) {
      throw StateError('Failed to render label bitmap.');
    }

    final rgba = byteData.buffer.asUint8List();
    final gray = Uint8List(width * height);
    for (var i = 0; i < gray.length; i++) {
      final offset = i * 4;
      final r = rgba[offset];
      final g = rgba[offset + 1];
      final b = rgba[offset + 2];
      gray[i] = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
    }
    return gray;
  }
}
