import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/core/printer/models/printer_calibration.dart';
import 'package:super_printer/core/printer/tspl_encoder.dart';

void main() {
  group('TsplEncoder.buildLabelTspl', () {
    test('header declares size in mm, density/speed from calibration, and PRINT copies', () {
      const encoder = TsplEncoder();
      final pixels = Uint8List.fromList(List.filled(8 * 8, 255)); // all white, 8x8
      final bytes = encoder.buildLabelTspl(
        pixels: pixels,
        width: 8,
        height: 8,
        labelWidthInches: 3,
        labelHeightInches: 6,
        calibration: const PrinterCalibration(darkness: 20, speedInchesPerSecond: 3),
        copies: 2,
      );

      // Everything up to the BITMAP command's binary payload is plain
      // ASCII, so it's safe to decode and inspect as text.
      final bitmapIndex = indexOfAscii(bytes, 'BITMAP');
      final header = ascii.decode(bytes.sublist(0, bitmapIndex));

      expect(header, contains('SIZE 76.2 mm,152.4 mm')); // 3in/6in -> mm
      expect(header, contains('GAP 2 mm,0 mm'));
      expect(header, contains('CLS'));
      // Darkness (20) rescaled from ZPL's 0-30 range into TSPL's 0-15
      // DENSITY range: 20/30*15 = 10.
      expect(header, contains('DENSITY 10'));
      expect(header, contains('SPEED 3'));

      final printIndex = indexOfAscii(bytes, 'PRINT');
      final footer = ascii.decode(bytes.sublist(printIndex));
      expect(footer, contains('PRINT 2,1'));
    });

    test(
        'default calibration (darkness 15, mid-range for ZPL) lands mid-range '
        'for TSPL too, not at DENSITY 15 (max) — the actual cause of solid-black prints',
        () {
      const encoder = TsplEncoder();
      final pixels = Uint8List.fromList(List.filled(8 * 8, 255));
      final bytes = encoder.buildLabelTspl(
        pixels: pixels,
        width: 8,
        height: 8,
        labelWidthInches: 3,
        labelHeightInches: 2,
      );

      final bitmapIndex = indexOfAscii(bytes, 'BITMAP');
      final header = ascii.decode(bytes.sublist(0, bitmapIndex));
      expect(header, contains('DENSITY 8'));
      expect(header, isNot(contains('DENSITY 15')));
    });

    test('bitmap payload is raw packed bytes, not text-encoded', () {
      const encoder = TsplEncoder();
      // A single all-black row (8 px) should pack to exactly one 0xFF byte
      // before polarity inversion — disabled here to test the packing
      // itself in isolation from the polarity question below.
      final pixels = Uint8List.fromList(List.filled(8, 0));
      final bytes = encoder.buildLabelTspl(
        pixels: pixels,
        width: 8,
        height: 1,
        labelWidthInches: 1,
        labelHeightInches: 1,
        invertPolarity: false,
      );

      final bitmapIndex = indexOfAscii(bytes, 'BITMAP 0,0,1,1,0,');
      final payloadStart = bitmapIndex + 'BITMAP 0,0,1,1,0,'.length;
      expect(bytes[payloadStart], 0xFF);
    });

    test(
        'polarity is inverted by default — confirmed against real hardware, '
        'where a 1-bit prints as unactivated/light, not black',
        () {
      const encoder = TsplEncoder();
      final pixels = Uint8List.fromList(List.filled(8, 0)); // all black
      final bytes = encoder.buildLabelTspl(
        pixels: pixels,
        width: 8,
        height: 1,
        labelWidthInches: 1,
        labelHeightInches: 1,
      );

      final bitmapIndex = indexOfAscii(bytes, 'BITMAP 0,0,1,1,0,');
      final payloadStart = bitmapIndex + 'BITMAP 0,0,1,1,0,'.length;
      // Inverted from the 0xFF an all-black row would otherwise pack to.
      expect(bytes[payloadStart], 0x00);
    });
  });
}

int indexOfAscii(List<int> bytes, String needle) {
  final pattern = ascii.encode(needle);
  for (var i = 0; i <= bytes.length - pattern.length; i++) {
    var matched = true;
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return i;
  }
  throw StateError('Pattern "$needle" not found');
}
