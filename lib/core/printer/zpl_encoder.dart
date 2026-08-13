import 'dart:typed_data';

import 'models/printer_calibration.dart';

/// Converts a rendered label bitmap into Zebra Programming Language (ZPL)
/// commands, using the `^GFA` (Graphic Field, ASCII hex) format.
///
/// This keeps printer communication decoupled from the label renderer: the
/// renderer only ever produces a plain white/black raster, and this class
/// is solely responsible for the Zebra wire format.
class ZplEncoder {
  const ZplEncoder();

  /// Builds a full ZPL job for one label.
  ///
  /// [pixels] must be a row-major grayscale buffer (one byte per pixel,
  /// 0 = black .. 255 = white) of size `width * height`, as produced by
  /// [LabelRenderer.renderToGrayscale]. Anything below [threshold] is
  /// printed black.
  String buildLabelZpl({
    required Uint8List pixels,
    required int width,
    required int height,
    PrinterCalibration calibration = const PrinterCalibration(),
    int threshold = 128,
  }) {
    final bytesPerRow = (width + 7) ~/ 8;
    final packed = Uint8List(bytesPerRow * height);

    for (var y = 0; y < height; y++) {
      final rowOffset = y * width;
      final packedRowOffset = y * bytesPerRow;
      for (var x = 0; x < width; x++) {
        final gray = pixels[rowOffset + x];
        if (gray < threshold) {
          final byteIndex = packedRowOffset + (x >> 3);
          final bitMask = 0x80 >> (x & 7);
          packed[byteIndex] = packed[byteIndex] | bitMask;
        }
      }
    }

    final hex = StringBuffer();
    for (final byte in packed) {
      hex.write(byte.toRadixString(16).padLeft(2, '0'));
    }

    final totalBytes = packed.length;
    final orientationCmd =
        calibration.orientation.name == 'inverted' ? '^POI' : '^PON';

    final buffer = StringBuffer()
      ..writeln('^XA')
      ..writeln('^MD${calibration.darkness}')
      ..writeln('^PR${calibration.speedInchesPerSecond}')
      ..writeln(orientationCmd)
      ..writeln('^LH${calibration.offsetXDots},${calibration.offsetYDots}')
      ..writeln('^FO0,0')
      ..writeln('^GFA,$totalBytes,$totalBytes,$bytesPerRow,${hex.toString()}')
      ..writeln('^XZ');

    return buffer.toString();
  }

  /// Builds a simple text-only ZPL test label, independent of the label
  /// renderer, so the printer settings screen can verify connectivity
  /// without going through the full rendering pipeline.
  String buildTestLabelZpl({
    required String printerName,
    required String labelSize,
    required int dpi,
    required String connectionType,
  }) {
    return '''
^XA
^CF0,30
^FO40,40^FDZEBRA TEST PRINT^FS
^CF0,24
^FO40,110^FDPrinter:^FS
^FO40,140^FD$printerName^FS
^FO40,190^FDLabel:^FS
^FO40,220^FD$labelSize^FS
^FO40,270^FDDPI:^FS
^FO40,300^FD$dpi^FS
^FO40,350^FDConnection:^FS
^FO40,380^FD$connectionType^FS
^FO40,430^FDStatus: SUCCESS^FS
^XZ
''';
  }
}
