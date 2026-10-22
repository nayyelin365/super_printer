import 'package:barcode/barcode.dart' as bc;

/// Barcode symbology selectable on the Sushi Template Label.
enum SushiBarcodeType { ean13, upcA }

extension SushiBarcodeTypeX on SushiBarcodeType {
  String get label => switch (this) {
        SushiBarcodeType.ean13 => 'EAN-13',
        SushiBarcodeType.upcA => 'UPC-A',
      };

  /// Exact digit count a value must have for this type, check digit
  /// included — the spec requires the full code, not an auto-completed one.
  int get digitLength => switch (this) {
        SushiBarcodeType.ean13 => 13,
        SushiBarcodeType.upcA => 12,
      };

  bc.Barcode get codec => switch (this) {
        SushiBarcodeType.ean13 => bc.Barcode.ean13(),
        SushiBarcodeType.upcA => bc.Barcode.upcA(),
      };

  /// Null when [value] is a valid, full (checksum-included) code for this
  /// type; otherwise a user-facing reason it isn't. Never truncates or
  /// otherwise modifies [value] — callers always see exactly what the user
  /// typed, just told whether it's usable.
  String? validate(String value) {
    if (value.isEmpty) return 'Enter a barcode value.';
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Barcode value must contain digits only.';
    }
    if (value.length != digitLength) {
      return '$label requires exactly $digitLength digits (including the check digit).';
    }
    try {
      codec.verify(value);
      return null;
    } on bc.BarcodeException catch (e) {
      return e.message;
    } catch (_) {
      return 'Invalid $label value.';
    }
  }

  bool isValid(String value) => validate(value) == null;
}
