import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'label_data.dart';
import 'label_template_renderer.dart';

/// Renderer for the "Custom Poke Bowl / Burrito" template.
///
/// Sections below the header are laid out with a running vertical cursor
/// rather than fixed y-coordinates, so optional/variable-length sections
/// (the itemized price list, the barcode) never leave a mismatched gap —
/// the whole content block is then centered in the space below the header.
class PokeBowlLabelRenderer extends LabelTemplateRenderer {
  const PokeBowlLabelRenderer();

  static const double designWidth = LabelCanvas.designWidth;
  static const double designHeight = LabelCanvas.designHeight;

  static const _headerHeight = 90.0;
  static const _nameSectionHeight = 60.0;
  static const _priceLineHeight = 40.0;
  static const _priceSectionMinHeight = 130.0;
  static const _noticeBoxHeight = 90.0;
  static const _noticeBoxGap = 10.0;
  static const _bottomSectionHeight = _noticeBoxHeight * 2 + _noticeBoxGap;
  static const _bottomMargin = 40.0;

  static const _bottomColumnGap = 30.0;
  static const _bottomColumnWidth = (designWidth - 80 - _bottomColumnGap) / 2;
  static const _barcodeHeight = 140.0;

  static const _accentGray = Color(0xFF6B7280);
  static const _dividerColor = Color(0xFF706E6E);
  static const _borderColor = Color(0xFFDBDBDB);
  static const _totalBoxColor = Color(0xFF10202E);

  static final _dateFormat = DateFormat('MM/dd/yyyy - hh:mm a');

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

    final lines = data.priceLines;
    // Always at least `_priceSectionMinHeight` — with only 1-2 items the
    // row-count-based height alone is shorter than the Total Price box
    // itself, which then overflows into the section below.
    final priceSectionHeight = lines.isEmpty
        ? _priceSectionMinHeight
        : ((lines.length / 2).ceil() * _priceLineHeight + 56).clamp(
            _priceSectionMinHeight,
            double.infinity,
          );

    // Header and the price section flow tight, top-to-bottom — no
    // artificial centering that stretched a big blank gap between the
    // header and product name when the price section had little content.
    // The barcode/notices, though, are anchored to the bottom of the
    // label rather than following the cursor, so they stay put instead of
    // drifting up whenever the price section above them is short.
    var cursor = _headerHeight;
    cursor = _paintProductName(canvas, data, cursor);
    _paintPriceSection(canvas, data, cursor, priceSectionHeight);
    _paintBottomSection(canvas, data, designHeight - _bottomMargin - _bottomSectionHeight);

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
      center: Offset(designWidth / 2, top + 14),
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

  /// The itemized price list (selected base price + each extra, two per
  /// row) on the left, and a "Total Price" box on the right.
  double _paintPriceSection(
    Canvas canvas,
    PokeBowlLabelData data,
    double top,
    double sectionHeight,
  ) {
    const itemStyle = TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w600);
    const totalLabelStyle = TextStyle(
      color: _accentGray,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );

    final lines = data.priceLines;
    final rightColumnWidth = 240.0;
    final leftColumnRight = designWidth - rightColumnWidth;
    final subColumnWidth = (leftColumnRight - 60) / 2;

    // Items split into two sub-columns (first half / second half) so a
    // handful of selections still reads compactly rather than running tall.
    final half = (lines.length / 2).ceil();
    for (var i = 0; i < lines.length; i++) {
      final column = i < half ? 0 : 1;
      final row = i < half ? i : i - half;
      final x = 40 + column * (subColumnWidth + 20);
      final y = top + 28 + row * _priceLineHeight;
      // Shrinks the font instead of truncating with "…" — a long base
      // price name (e.g. "Tofu / Vege Regular $11.00") should always be
      // fully readable, not cut off.
      _drawFittingText(
        canvas,
        '${lines[i].label} \$${lines[i].amount.toStringAsFixed(2)}',
        left: x,
        top: y,
        style: itemStyle,
        maxWidth: subColumnWidth,
      );
    }
    if (lines.isEmpty) {
      _drawText(
        canvas,
        'No items selected',
        left: 40,
        top: top + 28,
        style: itemStyle.copyWith(color: _accentGray),
      );
    }

    // Total Price box, right-aligned and top-anchored (not centered in the
    // section) so it stays close to the items list above it instead of
    // floating in the middle of a section sized for the tallest case.
    const boxHeight = 78.0;
    final boxTop = top + 40;
    final boxLeft = designWidth - 40 - rightColumnWidth + 20;
    final boxRect = Rect.fromLTWH(boxLeft, boxTop, rightColumnWidth - 20, boxHeight);

    _drawText(
      canvas,
      'TOTAL PRICE',
      center: Offset(boxRect.center.dx, boxTop - 22),
      style: totalLabelStyle,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect, const Radius.circular(8)),
      Paint()..color = _totalBoxColor,
    );
    _drawText(
      canvas,
      '\$${data.totalAmount.toStringAsFixed(2)}',
      center: boxRect.center,
      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800),
    );

    return top + sectionHeight;
  }

  /// Left: two bordered notices ("Perishable - Keep Refrigerated" and
  /// "Best if consumed within ..."). Right: packed date/time and, when
  /// enabled, the barcode.
  void _paintBottomSection(Canvas canvas, PokeBowlLabelData data, double top) {
    _paintNoticeBox(
      canvas,
      'Perishable -\nKeep Refrigerated',
      Rect.fromLTWH(40, top, _bottomColumnWidth, _noticeBoxHeight),
    );
    _paintNoticeBox(
      canvas,
      _bestIfConsumedText(data),
      Rect.fromLTWH(
        40,
        top + _noticeBoxHeight + _noticeBoxGap,
        _bottomColumnWidth,
        _noticeBoxHeight,
      ),
    );

    final rightLeft = 40 + _bottomColumnWidth + _bottomColumnGap;
    _drawText(
      canvas,
      'PACKED: ${_dateFormat.format(data.packedAt)}',
      left: rightLeft,
      top: top,
      style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w700),
    );
    if (data.showBarcode) {
      _paintBarcode(canvas, data, left: rightLeft, top: top + 40, width: _bottomColumnWidth);
    }
  }

  void _paintNoticeBox(Canvas canvas, String text, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawText(
      canvas,
      text,
      center: rect.center,
      style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w700),
      maxWidth: rect.width - 20,
      maxLines: 2,
    );
  }

  /// "Best if consumed within X hour(s)" for durations under a day, or
  /// "within X day(s)" from 24 hours on — no more "25+ days" style jumps,
  /// this only ever reflects the actual packed→use-by gap.
  String _bestIfConsumedText(PokeBowlLabelData data) {
    final hours = data.useBy.difference(data.packedAt).inHours;
    if (hours < 24) {
      return 'Best if consumed\nwithin $hours hour${hours == 1 ? '' : 's'}';
    }
    final days = (hours / 24).round();
    return 'Best if consumed\nwithin $days day${days == 1 ? '' : 's'}';
  }

  void _paintBarcode(
    Canvas canvas,
    PokeBowlLabelData data, {
    required double left,
    required double top,
    required double width,
  }) {
    const height = _barcodeHeight;
    const fontHeight = 18.0;

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
        style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign,
    )..layout(minWidth: element.width, maxWidth: element.width);
    painter.paint(canvas, Offset(originX + element.left, originY + element.top));
  }

  /// Draws [text] at [style]'s font size, shrinking it (down to
  /// [minFontSize]) until it fits [maxWidth] on one line — used where
  /// truncating with "…" would hide information the seller actually
  /// picked, e.g. a long base price name.
  void _drawFittingText(
    Canvas canvas,
    String text, {
    required double left,
    required double top,
    required TextStyle style,
    required double maxWidth,
    double minFontSize = 13,
  }) {
    var fitted = style;
    while ((fitted.fontSize ?? minFontSize) > minFontSize &&
        _measureText(text, fitted) > maxWidth) {
      fitted = fitted.copyWith(fontSize: fitted.fontSize! - 1);
    }
    _drawText(canvas, text, left: left, top: top, style: fitted);
  }

  double _measureText(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
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
    int maxLines = 1,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: center != null ? TextAlign.center : TextAlign.left,
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
