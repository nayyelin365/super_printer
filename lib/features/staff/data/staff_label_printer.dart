import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/printer/label_printer.dart';
import '../../../core/printer/models/label_size.dart';
import '../../../core/printer/models/printer_calibration.dart';
import '../../../core/printer/printer_exceptions.dart';
import '../../../core/printer/printer_session_controller.dart';

/// The Staff ID badge label: name, role, and a QR code encoding the
/// employee's Firestore doc id — printed via "Save & Print QR" on the
/// Employee form, or again later from a roster row's print icon.
///
/// Deliberately a standalone rendered bitmap rather than a new
/// `LabelData`/`LabelTemplate`, matching the Sushi Rice SOP's labels
/// (`sushi_rice_label_printer.dart`): this prints programmatically from
/// its own screen, not through the interactive template/print flow, so it
/// doesn't need to join that system.
class StaffLabelPrintResult {
  const StaffLabelPrintResult({required this.success, this.errorMessage});
  final bool success;
  final String? errorMessage;
}

Future<StaffLabelPrintResult> printStaffIdLabel(
  WidgetRef ref, {
  required String employeeId,
  required String name,
  required String role,
}) async {
  final session = ref.read(printerSessionProvider);
  final printer = ref.read(printerSessionProvider.notifier).printer;

  if (printer == null || session.status != PrinterConnectionStatus.connected) {
    return const StaffLabelPrintResult(
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
    final bitmap = await _renderStaffIdLabel(
      employeeId: employeeId,
      name: name,
      role: role,
      width: pixels.width,
      height: pixels.height,
    );
    await printer.printImage(
      bitmap,
      width: pixels.width,
      height: pixels.height,
      calibration: calibration,
    );
    return const StaffLabelPrintResult(success: true);
  } on PrinterException catch (e) {
    return StaffLabelPrintResult(success: false, errorMessage: e.message);
  } catch (_) {
    return const StaffLabelPrintResult(
      success: false,
      errorMessage: 'Printing failed. Please try again.',
    );
  }
}

const double _designWidth = 900;
const double _designHeight = 600;

Future<Uint8List> _renderStaffIdLabel({
  required String employeeId,
  required String name,
  required String role,
  required int width,
  required int height,
}) {
  return _renderGrayscale(
    width: width,
    height: height,
    paint: (canvas) {
      _paintText(
        canvas,
        'STAFF ID',
        rect: const Rect.fromLTWH(0, 24, _designWidth, 40),
        fontSize: 28,
        fontWeight: FontWeight.bold,
      );

      const qrSize = 320.0;
      _paintQrCode(
        canvas,
        employeeId,
        rect: const Rect.fromLTWH((_designWidth - qrSize) / 2, 76, qrSize, qrSize),
      );

      _paintText(
        canvas,
        name,
        rect: const Rect.fromLTWH(24, 418, _designWidth - 48, 56),
        fontSize: 42,
        fontWeight: FontWeight.bold,
      );
      if (role.isNotEmpty) {
        _paintText(
          canvas,
          role,
          rect: const Rect.fromLTWH(24, 482, _designWidth - 48, 36),
          fontSize: 26,
          color: Colors.black54,
        );
      }
    },
  );
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

  canvas.drawRect(const Rect.fromLTWH(0, 0, _designWidth, _designHeight), Paint()..color = Colors.white);

  paint(canvas);

  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (byteData == null) {
    throw StateError('Failed to render Staff ID label bitmap.');
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
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight)),
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
        Rect.fromLTWH(rect.left + element.left, rect.top + element.top, element.width, element.height),
        Paint()..color = Colors.black,
      );
    }
  }
}
