import 'dart:typed_data';

import 'models/printer_calibration.dart';

/// Converts a rendered label bitmap into TSPL (TSC Printer Language)
/// commands — the command set most non-Zebra thermal printers ("Other
/// Printer" in Printer Settings) actually speak, as opposed to Zebra's own
/// ZPL (see [ZplEncoder]). Unlike ZPL's `^GFA` (which embeds the bitmap as
/// ASCII hex), TSPL's `BITMAP` command embeds it as raw binary bytes
/// directly in the command stream — so this returns a plain byte list,
/// never a [String], to avoid corrupting that binary payload through a
/// text encoding.
class TsplEncoder {
  const TsplEncoder();

  /// Builds a full TSPL job: `SIZE`/`GAP`/`DIRECTION`/`REFERENCE`/
  /// `DENSITY`/`SPEED` setup, the `BITMAP` command carrying [pixels], then
  /// `PRINT` for [copies] copies.
  ///
  /// [pixels] must be a row-major grayscale buffer (one byte per pixel,
  /// 0 = black .. 255 = white) of size `width * height`, as produced by
  /// [LabelTemplateRenderer.renderToGrayscale] — the same input
  /// [ZplEncoder.buildLabelZpl] takes. [labelWidthInches]/
  /// [labelHeightInches] are the label's physical size (TSPL's `SIZE`
  /// command needs the real dimensions, unlike ZPL which only works in
  /// dots).
  List<int> buildLabelTspl({
    required Uint8List pixels,
    required int width,
    required int height,
    required double labelWidthInches,
    required double labelHeightInches,
    PrinterCalibration calibration = const PrinterCalibration(),
    int threshold = 128,
    int copies = 1,
    // Confirmed against real hardware: this printer's BITMAP bit polarity
    // is the reverse of the documented TSPL convention — a 1-bit prints
    // as unactivated/light, a 0-bit as activated/black (the opposite of
    // ZPL's ^GFA and of what TSPL's own spec describes). Without this,
    // the whole background prints black and black content (e.g. a
    // filled price box) prints as the unprinted paper color instead —
    // exactly what was observed. Default true since that's what every
    // TSPL printer tested against so far needs; left as a parameter in
    // case a future unit turns out to use the standard polarity.
    bool invertPolarity = true,
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

    if (invertPolarity) {
      for (var i = 0; i < packed.length; i++) {
        packed[i] = packed[i] ^ 0xFF;
      }
    }

    final widthMm = labelWidthInches * 25.4;
    final heightMm = labelHeightInches * 25.4;
    // PrinterCalibration.darkness is calibrated for ZPL's ^MD range
    // (documented as "0-30 on most Zebra printers" — 15, its default, is
    // roughly the middle of that). TSPL's DENSITY only goes 0-15, so
    // reusing the raw value directly fed the printer its *maximum*
    // density at the default setting — which is almost certainly why
    // everything printed solid black. Rescale proportionally instead, so
    // the same "default" calibration lands mid-range for TSPL too.
    final density = (calibration.darkness / 30 * 15).round().clamp(0, 15);
    final speed = calibration.speedInchesPerSecond;
    final direction = calibration.orientation == PrintOrientation.inverted ? 1 : 0;
    final copyCount = copies < 1 ? 1 : copies;

    final commands = <int>[];
    void addLine(String cmd) {
      commands.addAll(cmd.codeUnits);
      commands.add(0x0D); // CR
      commands.add(0x0A); // LF
    }

    addLine('SIZE ${widthMm.toStringAsFixed(1)} mm,${heightMm.toStringAsFixed(1)} mm');
    addLine('GAP 2 mm,0 mm');
    addLine('DIRECTION $direction,0');
    addLine('REFERENCE ${calibration.offsetXDots},${calibration.offsetYDots}');
    addLine('CLS');
    addLine('DENSITY $density');
    addLine('SPEED $speed');

    // BITMAP's payload is raw binary, not ASCII — appended directly after
    // the command header, with no encoding step, then closed with a plain
    // CRLF before the next ASCII command line.
    commands.addAll('BITMAP 0,0,$bytesPerRow,$height,0,'.codeUnits);
    commands.addAll(packed);
    commands.add(0x0D);
    commands.add(0x0A);

    addLine('PRINT $copyCount,1');

    return commands;
  }

  /// Builds a simple text-only TSPL test label, independent of the label
  /// renderer, mirroring [ZplEncoder.buildTestLabelZpl] for non-Zebra
  /// printers' Test Print.
  List<int> buildTestLabelTspl({
    required String printerName,
    required String labelSize,
    required int dpi,
    required String connectionType,
  }) {
    final commands = <int>[];
    void addLine(String cmd) {
      commands.addAll(cmd.codeUnits);
      commands.add(0x0D);
      commands.add(0x0A);
    }

    addLine('SIZE 76.0 mm,51.0 mm');
    addLine('GAP 2 mm,0 mm');
    addLine('DIRECTION 0,0');
    addLine('REFERENCE 0,0');
    addLine('CLS');
    addLine('DENSITY 8');
    addLine('SPEED 2');
    addLine('TEXT 40,20,"3",0,1,1,"TSPL TEST PRINT"');
    addLine('TEXT 40,60,"2",0,1,1,"Printer: $printerName"');
    addLine('TEXT 40,90,"2",0,1,1,"Label: $labelSize"');
    addLine('TEXT 40,120,"2",0,1,1,"DPI: $dpi"');
    addLine('TEXT 40,150,"2",0,1,1,"Connection: $connectionType"');
    addLine('TEXT 40,190,"2",0,1,1,"Status: SUCCESS"');
    addLine('PRINT 1,1');

    return commands;
  }
}
