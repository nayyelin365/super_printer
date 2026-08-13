import 'dart:typed_data';

import 'models/printer_calibration.dart';

/// Converts a rendered label bitmap into Zebra Programming Language (ZPL)
/// commands, using the `^GFA` (Graphic Field, ASCII hex) format with
/// Zebra's "Alternative Data Compression Scheme" (ACS) run-length
/// encoding — the standard way to shrink `^GFA` payloads sent over a slow
/// link such as classic Bluetooth SPP.
///
/// This keeps printer communication decoupled from the label renderer: the
/// renderer only ever produces a plain white/black raster, and this class
/// is solely responsible for the Zebra wire format.
class ZplEncoder {
  const ZplEncoder();

  // ACS repeat-count alphabet: uppercase G-Y = 1-19 repeats, lowercase
  // g-y = 20-380 in steps of 20, 'z' = 400 (index 0 is an unused '_'
  // placeholder so `len` can index directly).
  static const _acsUnits = '_GHIJKLMNOPQRSTUVWXY';
  static const _acsTens = '_ghijklmnopqrstuvwxy';

  /// Builds a full ZPL job, optionally printing [copies] labels from a
  /// single transmitted image via `^PQ` (cheaper than re-sending the whole
  /// bitmap once per copy).
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
    int copies = 1,
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

    final compressed = _compressAcs(packed);
    final speed = calibration.speedInchesPerSecond;
    final orientationCmd =
        calibration.orientation == PrintOrientation.inverted ? '^POI' : '^PON';
    final copyCount = copies < 1 ? 1 : copies;

    final buffer = StringBuffer()
      ..writeln('^XA')
      ..writeln('^MD${calibration.darkness}')
      ..writeln('^PR$speed,$speed,$speed')
      ..writeln(orientationCmd)
      ..writeln('^PW$width')
      ..writeln('^LL$height')
      ..writeln('^LH${calibration.offsetXDots},${calibration.offsetYDots}')
      ..writeln('^FO0,0')
      ..writeln('^GFA,${compressed.length},${packed.length},$bytesPerRow,$compressed')
      ..writeln('^PQ$copyCount,0,1,Y')
      ..writeln('^XZ');

    return buffer.toString();
  }

  /// Applies Zebra's Alternative Data Compression Scheme to a packed 1bpp
  /// bitmap: runs of 3+ identical hex nibbles are replaced with a repeat
  /// count letter followed by the nibble. Ported from the reference
  /// implementation in metafloor/zpl-image (`rgbaToACS`).
  String _compressAcs(Uint8List packed) {
    final hex = StringBuffer();
    for (final byte in packed) {
      hex.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    final hexStr = hex.toString();

    final runPattern = RegExp(r'([0-9a-fA-F])\1{2,}');
    final acs = StringBuffer();
    var offset = 0;

    for (final match in runPattern.allMatches(hexStr)) {
      acs.write(hexStr.substring(offset, match.start));

      var len = match.group(0)!.length;
      while (len >= 400) {
        acs.write('z');
        len -= 400;
      }
      if (len >= 20) {
        acs.write(_acsTens[len ~/ 20]);
        len %= 20;
      }
      if (len > 0) {
        acs.write(_acsUnits[len]);
      }
      acs.write(match.group(1));

      offset = match.end;
    }
    acs.write(hexStr.substring(offset));

    return acs.toString();
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
