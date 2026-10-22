import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/label_printing/domain/sushi_barcode.dart';

void main() {
  group('SushiBarcodeType.validate', () {
    test('EAN-13: accepts a correct 13-digit value', () {
      expect(SushiBarcodeType.ean13.validate('4006381333931'), isNull);
      expect(SushiBarcodeType.ean13.isValid('4006381333931'), isTrue);
    });

    test('EAN-13: rejects a wrong-length value, never silently truncating', () {
      final error = SushiBarcodeType.ean13.validate('400638133393');
      expect(error, isNotNull);
      expect(error, contains('13 digits'));
    });

    test('EAN-13: rejects a bad checksum', () {
      final error = SushiBarcodeType.ean13.validate('4006381333932');
      expect(error, isNotNull);
      expect(SushiBarcodeType.ean13.isValid('4006381333932'), isFalse);
    });

    test('UPC-A: accepts a correct 12-digit value', () {
      expect(SushiBarcodeType.upcA.validate('036000291452'), isNull);
      expect(SushiBarcodeType.upcA.isValid('036000291452'), isTrue);
    });

    test('UPC-A: rejects a bad checksum', () {
      expect(SushiBarcodeType.upcA.isValid('036000291450'), isFalse);
    });

    test('rejects non-digit characters with a clear message', () {
      final error = SushiBarcodeType.ean13.validate('400638133393a');
      expect(error, contains('digits only'));
    });

    test('rejects an empty value', () {
      expect(SushiBarcodeType.ean13.validate(''), isNotNull);
    });

    test('digitLength matches each symbology', () {
      expect(SushiBarcodeType.ean13.digitLength, 13);
      expect(SushiBarcodeType.upcA.digitLength, 12);
    });
  });
}
