import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'food_rotation_label_data.dart';
import 'label_data.dart';
import 'label_template_renderer.dart';

/// Renderer for the "Food Rotation Label" template: food name, prep
/// date/time, a boxed use-by date, and the employee who prepped it. No
/// weight/price/barcode — those belong to [PokeBowlLabelData] only.
class FoodRotationLabelRenderer extends LabelTemplateRenderer {
  const FoodRotationLabelRenderer();

  static const double designWidth = LabelCanvas.designWidth;
  static const double designHeight = LabelCanvas.designHeight;

  static const _borderColor = Color(0xFFDBDBDB);
  static const _boxColor = Color(0xFF10202E);

  static final _dateFormat = DateFormat('MM/dd/yyyy hh:mm a');

  @override
  void paint(Canvas canvas, Size outputSize, LabelData data) {
    final rotation = data as FoodRotationLabelData;
    canvas.save();
    canvas.scale(
      outputSize.width / designWidth,
      outputSize.height / designHeight,
    );
    _paintAtDesignScale(canvas, rotation);
    canvas.restore();
  }

  void _paintAtDesignScale(Canvas canvas, FoodRotationLabelData data) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, designWidth, designHeight),
      Paint()..color = Colors.white,
    );

    _paintFoodName(canvas, data);
    _paintPrepDateTime(canvas, data);
    _paintUseByBox(canvas, data);
    _paintEmployee(canvas, data);
    _paintOuterBorder(canvas);
  }

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

  void _paintFoodName(Canvas canvas, FoodRotationLabelData data) {
    final name = data.foodName.trim().isEmpty
        ? 'UNNAMED ITEM'
        : data.foodName.toUpperCase();
    _drawText(
      canvas,
      name,
      center: const Offset(designWidth / 2, 110),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 42,
        fontWeight: FontWeight.w800,
      ),
      maxWidth: designWidth - 60,
    );
  }

  void _paintPrepDateTime(Canvas canvas, FoodRotationLabelData data) {
    _drawText(
      canvas,
      'PREP DATE & TIME: ${_dateFormat.format(data.prepDateTime)}',
      left: 40,
      top: 210,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _paintUseByBox(Canvas canvas, FoodRotationLabelData data) {
    const boxRect = Rect.fromLTWH(40, 280, designWidth - 80, 100);
    canvas.drawRect(
      boxRect,
      Paint()
        ..color = _boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _drawText(
      canvas,
      'USE BY: ${_dateFormat.format(data.useBy)}',
      center: boxRect.center,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 30,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  void _paintEmployee(Canvas canvas, FoodRotationLabelData data) {
    final employee = data.employee.trim().isEmpty ? '-' : data.employee.trim();
    final text = 'EMPLOYEE: $employee';
    const style = TextStyle(
      color: Colors.black,
      fontSize: 26,
      fontWeight: FontWeight.w700,
    );
    final width = _measureText(text, style);
    _drawText(
      canvas,
      text,
      left: designWidth - 40 - width,
      top: 460,
      style: style,
    );
  }

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

  double _measureText(String text, TextStyle style, {double? maxWidth}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth ?? designWidth);
    return painter.width;
  }
}
