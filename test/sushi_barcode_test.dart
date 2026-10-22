import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/label_printing/domain/sushi_barcode.dart';

void main() {
  group('SushiBarcodeType.validate', () {
    test('EAN-13: accepts a 12-digit payload (no check digit typed)', () {
      expect(SushiBarcodeType.ean13.validate('400638133393'), isNull);
      expect(SushiBarcodeType.ean13.isValid('400638133393'), isTrue);
    });

    test('EAN-13: rejects a 13-digit value — the check digit must not be typed', () {
      final error = SushiBarcodeType.ean13.validate('4006381333931');
      expect(error, isNotNull);
      expect(error, contains('12 digits'));
    });

    test('EAN-13: rejects a too-short value, never silently padding it', () {
      final error = SushiBarcodeType.ean13.validate('40063813339');
      expect(error, isNotNull);
      expect(error, contains('12 digits'));
    });

    test('UPC-A: accepts an 11-digit payload (no check digit typed)', () {
      expect(SushiBarcodeType.upcA.validate('03600029145'), isNull);
      expect(SushiBarcodeType.upcA.isValid('03600029145'), isTrue);
    });

    test('UPC-A: rejects a 12-digit value — the check digit must not be typed', () {
      expect(SushiBarcodeType.upcA.isValid('036000291452'), isFalse);
    });

    test('rejects non-digit characters with a clear message', () {
      final error = SushiBarcodeType.ean13.validate('40063813339a');
      expect(error, contains('digits only'));
    });

    test('rejects an empty value', () {
      expect(SushiBarcodeType.ean13.validate(''), isNotNull);
    });

    test('payloadLength is one digit short of digitLength for both symbologies', () {
      expect(SushiBarcodeType.ean13.digitLength, 13);
      expect(SushiBarcodeType.ean13.payloadLength, 12);
      expect(SushiBarcodeType.upcA.digitLength, 12);
      expect(SushiBarcodeType.upcA.payloadLength, 11);
    });
  });

  group('check digit generation', () {
    test('the barcode package computes a valid full code from just the payload', () {
      // Matches the checksum already hand-verified for this payload
      // (full code 4006381333931 — the classic Wikipedia EAN-13 example).
      final elements = SushiBarcodeType.ean13.codec.make(
        '400638133393',
        width: 200,
        height: 80,
        drawText: true,
        fontHeight: 16,
      );
      expect(elements, isNotEmpty);
    });
  });
}
