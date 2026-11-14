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

  static final _dateFormat = DateFormat('MM/dd/yyyy - hh:mm a');

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

    // Ingredients (3-5 lines) needs real room, so when it's shown
    // everything above it is tightened up a bit — food name moves up
    // slightly, and the gaps between PH/prep date/the use-by box/employee
    // all shrink — rather than ingredients competing for the same fixed
    // layout and overflowing or getting cramped. With it hidden, every
    // position/size below is exactly what it always was.
    final compact = data.showIngredients;

    _paintFoodName(canvas, data, centerY: compact ? 90 : 110);

    // PH sits right under the food name; when hidden, prep date/time and
    // the use-by box shift up to take its place rather than leaving a gap.
    var top = compact ? 170.0 : 210.0;
    if (data.showPh) {
      _paintPh(canvas, data, compact ? 125 : 160);
      top = compact ? 195 : 230;
    }

    _paintPrepDateTime(canvas, data, top);

    final boxTop = top + (compact ? 55 : 70);
    final boxHeight = compact ? 80.0 : 100.0;
    final boxFontSize = compact ? 36.0 : 42.0;
    _paintUseByBox(canvas, data, boxTop, height: boxHeight, fontSize: boxFontSize);

    const employeeFontSize = 40.0;
    final employeeCenterY = compact ? boxTop + boxHeight + 45 : 460.0;
    _paintEmployee(canvas, data, centerY: employeeCenterY, fontSize: employeeFontSize);

    if (data.showIngredients) {
      // 4px smaller than Employee, per request.
      _paintIngredients(canvas, data, top: employeeCenterY + 35, fontSize: employeeFontSize - 4);
    }

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

  void _paintFoodName(Canvas canvas, FoodRotationLabelData data, {required double centerY}) {
    final name = data.foodName.trim().isEmpty
        ? 'UNNAMED ITEM'
        : data.foodName.toUpperCase();
    _drawText(
      canvas,
      name,
      center: Offset(designWidth / 2, centerY),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 45,
        fontWeight: FontWeight.w800,
      ),
      maxWidth: designWidth - 60,
      maxLines: 2,
    );
  }

  /// Directly under the food name — only painted when
  /// [FoodRotationLabelData.showPh] is true; the caller shifts everything
  /// below it down to make room, rather than this leaving a gap when hidden.
  void _paintPh(Canvas canvas, FoodRotationLabelData data, double top) {
    final ph = data.ph.trim().isEmpty ? '-' : data.ph.trim();
    _drawText(
      canvas,
      'PH: $ph',
      left: 40,
      top: top,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 40,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _paintPrepDateTime(Canvas canvas, FoodRotationLabelData data, double top) {
    _drawText(
      canvas,
      'PREP DATE & TIME: ${_dateFormat.format(data.prepDateTime)}',
      left: 40,
      top: top,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 40,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _paintUseByBox(
    Canvas canvas,
    FoodRotationLabelData data,
    double top, {
    required double height,
    required double fontSize,
  }) {
    final boxRect = Rect.fromLTWH(40, top, designWidth - 80, height);
    canvas.drawRect(
      boxRect,
      Paint()
        ..color = _boxColor
        ..style = PaintingStyle.fill,
    );
    _drawText(
      canvas,
      'USE BY: ${_dateFormat.format(data.useBy)}',
      center: boxRect.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  void _paintEmployee(
    Canvas canvas,
    FoodRotationLabelData data, {
    required double centerY,
    required double fontSize,
  }) {
    final style = TextStyle(
      color: Colors.black,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );

    final employee = data.employee.trim().isEmpty ? '-' : data.employee.trim();
    final text = 'EMPLOYEE: $employee';
    _drawText(
      canvas,
      text,
      center: Offset(designWidth / 2, centerY),
      style: style,
    );
  }

  /// Under Employee — only painted when
  /// [FoodRotationLabelData.showIngredients] is true. Left-aligned,
  /// wrapping across up to 5 lines (the expected 3-5 line range), which
  /// is why the caller compresses the layout above it to free up room
  /// here rather than this competing for a fixed slot.
  void _paintIngredients(
    Canvas canvas,
    FoodRotationLabelData data, {
    required double top,
    required double fontSize,
  }) {
    final text = data.ingredientsText.trim();
    if (text.isEmpty) return;
    _drawText(
      canvas,
      text,
      left: 40,
      top: top,
      style: TextStyle(
        color: Colors.black,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
      maxWidth: designWidth - 80,
      maxLines: 5,
      textAlign: TextAlign.left,
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
    int maxLines = 1,
    TextAlign textAlign = TextAlign.center,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign,
      ellipsis: maxWidth != null ? '…' : null,
      maxLines: maxLines,
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
}
