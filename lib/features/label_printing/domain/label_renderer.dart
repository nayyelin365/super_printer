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

  static const _headerColor = Color(0xFF10202E);
  static const _accentGray = Color(0xFF6B7280);
  static const _dividerColor = Color(0xFFD8DCE1);

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
  }

  void _paintHeader(Canvas canvas) {
    const headerHeight = 64.0;
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
        fontSize: 30,
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
      center: const Offset(designWidth / 2, 106),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: designWidth - 60,
    );
    canvas.drawLine(
      const Offset(40, 142),
      const Offset(designWidth - 40, 142),
      Paint()
        ..color = _dividerColor
        ..strokeWidth = 2,
    );
  }

  void _paintInfoRow(Canvas canvas, LabelData data) {
    const top = 158.0;
    const labelStyle = TextStyle(
      color: _accentGray,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );
    const valueStyle = TextStyle(
      color: Colors.black,
      fontSize: 24,
      fontWeight: FontWeight.w700,
    );
    const totalValueStyle = TextStyle(
      color: Colors.black,
      fontSize: 30,
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
      const Offset(40, 218),
      const Offset(designWidth - 40, 218),
      Paint()
        ..color = _dividerColor
        ..strokeWidth = 2,
    );
  }

  void _paintDates(Canvas canvas, LabelData data) {
    const top = 244.0;
    const labelStyle = TextStyle(
      color: Colors.black,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );

    _drawText(
      canvas,
      'PACKED: ${_dateFormat.format(data.packedAt)}',
      left: 40,
      top: top,
      style: labelStyle,
    );
    _drawText(
      canvas,
      'USE BY: ${_dateFormat.format(data.useBy)}',
      left: 40,
      top: top + 26,
      style: labelStyle,
    );
  }

  void _paintBarcode(Canvas canvas, LabelData data) {
    const left = 60.0;
    const top = 320.0;
    const width = designWidth - 120;
    const height = 190.0;

    final code = data.barcode.trim();
    if (code.isEmpty) return;

    final barcode = Barcode.code128();
    if (!barcode.isValid(code)) return;

    for (final element in barcode.make(
      code,
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
      code,
      center: Offset(designWidth / 2, top + height + 18),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        letterSpacing: 3,
      ),
    );
  }

  void _drawText(
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
