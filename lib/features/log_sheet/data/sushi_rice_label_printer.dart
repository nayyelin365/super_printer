import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/printer/label_printer.dart';
import '../../../core/printer/models/label_size.dart';
import '../../../core/printer/models/printer_calibration.dart';
import '../../../core/printer/printer_exceptions.dart';
import '../../../core/printer/printer_session_controller.dart';
import '../domain/sushi_rice_batch.dart';

/// Two fixed-layout QR labels for a Sushi Rice batch, both printed via
/// "Save & Print" at different points in the SOP:
/// [printSushiRiceBatchLabel] at batch creation (Soaking start), and
/// [printSushiRiceTphcLabel] once pH verification passes (starting the
/// 24-Hr TPHC window).
///
/// Deliberately standalone rather than a new `LabelData`/`LabelTemplate`:
/// these print programmatically, not through the interactive template/
/// print screen, and adding new template types would ripple into the
/// unrelated existing print feature (template catalog, selection screen,
/// renderer dispatch) for labels only this one flow ever produces.
class SushiRiceLabelPrintResult {
  const SushiRiceLabelPrintResult({required this.success, this.errorMessage});
  final bool success;
  final String? errorMessage;
}

Future<SushiRiceLabelPrintResult> printSushiRiceBatchLabel(
  Ref ref, {
  required String batchCode,
  required DateTime prepDateTime,
  required DateTime? soakEndsAt,
  required String employeeName,
}) {
  return _print(
    ref,
    (width, height) => _renderBatchLabel(
      batchCode: batchCode,
      prepDateTime: prepDateTime,
      soakEndsAt: soakEndsAt,
      employeeName: employeeName,
      width: width,
      height: height,
    ),
  );
}

/// The 24-Hr TPHC compliance label — printed once pH passes, showing the
/// reading and the Ready-to-Use deadline rather than the soak deadline.
Future<SushiRiceLabelPrintResult> printSushiRiceTphcLabel(
  Ref ref, {
  required String batchCode,
  required double phReading,
  required DateTime prepDateTime,
  required DateTime useBy,
  required String employeeName,
}) {
  return _print(
    ref,
    (width, height) => _renderTphcLabel(
      batchCode: batchCode,
      phReading: phReading,
      prepDateTime: prepDateTime,
      useBy: useBy,
      employeeName: employeeName,
      width: width,
      height: height,
    ),
  );
}

Future<SushiRiceLabelPrintResult> _print(
  Ref ref,
  Future<Uint8List> Function(int width, int height) render,
) async {
  final session = ref.read(printerSessionProvider);
  final printer = ref.read(printerSessionProvider.notifier).printer;

  if (printer == null || session.status != PrinterConnectionStatus.connected) {
    return const SushiRiceLabelPrintResult(
      success: false,
      errorMessage: 'Printer is not connected. Please connect a printer before printing.',
    );
  }

  final config = session.config;
  final dpi = config?.dpi ?? 300;
  final labelSize = config?.labelSize ?? LabelSize.threeByTwo;
  final pixels = labelSize.pixelSize(dpi);
  final calibration = config?.calibration ?? const PrinterCalibration();

  try {
    final bitmap = await render(pixels.width, pixels.height);
    await printer.printImage(
      bitmap,
      width: pixels.width,
      height: pixels.height,
      calibration: calibration,
    );
    return const SushiRiceLabelPrintResult(success: true);
  } on PrinterException catch (e) {
    return SushiRiceLabelPrintResult(success: false, errorMessage: e.message);
  } catch (_) {
    return const SushiRiceLabelPrintResult(
      success: false,
      errorMessage: 'Printing failed. Please try again.',
    );
  }
}

const double _designWidth = 900;
const double _designHeight = 600;

Future<Uint8List> _renderBatchLabel({
  required String batchCode,
  required DateTime prepDateTime,
  required DateTime? soakEndsAt,
  required String employeeName,
  required int width,
  required int height,
}) {
  return _renderGrayscale(width: width, height: height, paint: (canvas) {
    _paintText(
      canvas,
      'Sushi Rice',
      rect: const Rect.fromLTWH(24, 20, 500, 50),
      fontSize: 40,
      fontWeight: FontWeight.bold,
      align: TextAlign.left,
    );

    _paintQrCode(canvas, batchCode, rect: const Rect.fromLTWH(680, 20, 196, 196));

    final dateFormat = DateFormat('d MMM yyyy (EEE) h:mma');
    _paintLabelValueRow(canvas, 'Batch No:', batchCode, top: 260);
    _paintLabelValueRow(canvas, 'Prep Date/Time:', dateFormat.format(prepDateTime), top: 300);

    if (soakEndsAt != null) {
      canvas.drawRect(
        const Rect.fromLTWH(24, 360, _designWidth - 48, 70),
        Paint()..color = Colors.black,
      );
      _paintText(
        canvas,
        'Soak Until: ${DateFormat('EEEE h:mma').format(soakEndsAt).toUpperCase()}',
        rect: const Rect.fromLTWH(24, 380, _designWidth - 48, 34),
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );
    }

    _paintText(
      canvas,
      'Employee: $employeeName',
      rect: const Rect.fromLTWH(24, 460, _designWidth - 48, 30),
      fontSize: 20,
      align: TextAlign.right,
    );
  });
}

Future<Uint8List> _renderTphcLabel({
  required String batchCode,
  required double phReading,
  required DateTime prepDateTime,
  required DateTime useBy,
  required String employeeName,
  required int width,
  required int height,
}) {
  return _renderGrayscale(width: width, height: height, paint: (canvas) {
    _paintText(
      canvas,
      'Sushi Rice',
      rect: const Rect.fromLTWH(24, 20, 500, 50),
      fontSize: 40,
      fontWeight: FontWeight.bold,
      align: TextAlign.left,
    );
    _paintText(
      canvas,
      '${phReading.toStringAsFixed(1)} pH',
      rect: const Rect.fromLTWH(24, 70, 400, 40),
      fontSize: 30,
      fontWeight: FontWeight.bold,
      align: TextAlign.left,
    );

    _paintQrCode(canvas, batchCode, rect: const Rect.fromLTWH(680, 20, 196, 196));

    final dateFormat = DateFormat('d MMM yyyy (EEE) h:mma');
    _paintLabelValueRow(canvas, 'Batch No:', batchCode, top: 260);
    _paintLabelValueRow(canvas, 'Prep Date/Time:', dateFormat.format(prepDateTime), top: 300);

    canvas.drawRect(
      const Rect.fromLTWH(24, 360, _designWidth - 48, 70),
      Paint()..color = Colors.black,
    );
    _paintText(
      canvas,
      'Use by: ${DateFormat('EEEE h:mma').format(useBy).toUpperCase()}',
      rect: const Rect.fromLTWH(24, 380, _designWidth - 48, 34),
      fontSize: 26,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    _paintText(
      canvas,
      '$sushiRiceReadyToUseWindowHours hr TPHC Window',
      rect: const Rect.fromLTWH(24, 440, 400, 26),
      fontSize: 16,
      color: Colors.black54,
      align: TextAlign.left,
    );
    _paintText(
      canvas,
      'Employee: $employeeName',
      rect: const Rect.fromLTWH(24, 460, _designWidth - 48, 30),
      fontSize: 20,
      align: TextAlign.right,
    );
  });
}

Future<Uint8List> _renderGrayscale({
  required int width,
  required int height,
  required void Function(Canvas canvas) paint,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  canvas.save();
  canvas.scale(width / _designWidth, height / _designHeight);

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _designWidth, _designHeight),
    Paint()..color = Colors.white,
  );

  paint(canvas);

  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (byteData == null) {
    throw StateError('Failed to render Sushi Rice label bitmap.');
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

void _paintLabelValueRow(Canvas canvas, String label, String value, {required double top}) {
  _paintText(
    canvas,
    label,
    rect: Rect.fromLTWH(24, top, 300, 26),
    fontSize: 16,
    color: Colors.black54,
    align: TextAlign.left,
  );
  _paintText(
    canvas,
    value,
    rect: Rect.fromLTWH(24, top + 24, 500, 30),
    fontSize: 22,
    fontWeight: FontWeight.bold,
    align: TextAlign.left,
  );
}

void _paintText(
  Canvas canvas,
  String text, {
  required Rect rect,
  required double fontSize,
  FontWeight fontWeight = FontWeight.normal,
  Color color = Colors.black,
  TextAlign align = TextAlign.center,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
    ),
    textAlign: align,
    textDirection: ui.TextDirection.ltr,
  )..layout(maxWidth: rect.width);
  final dx = switch (align) {
    TextAlign.right => rect.left + rect.width - painter.width,
    TextAlign.center => rect.left + (rect.width - painter.width) / 2,
    _ => rect.left,
  };
  painter.paint(canvas, Offset(dx, rect.top));
}

void _paintQrCode(Canvas canvas, String data, {required Rect rect}) {
  final barcode = bc.Barcode.qrCode(errorCorrectLevel: bc.BarcodeQRCorrectionLevel.medium);
  for (final element in barcode.make(data, width: rect.width, height: rect.height)) {
    if (element is bc.BarcodeBar && element.black) {
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + element.left,
          rect.top + element.top,
          element.width,
          element.height,
        ),
        Paint()..color = Colors.black,
      );
    }
  }
}
