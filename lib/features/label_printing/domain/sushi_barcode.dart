import 'package:barcode/barcode.dart' as bc;

/// Barcode symbology selectable on the Sushi Template Label.
enum SushiBarcodeType { ean13, upcA }

extension SushiBarcodeTypeX on SushiBarcodeType {
  String get label => switch (this) {
        SushiBarcodeType.ean13 => 'EAN-13',
        SushiBarcodeType.upcA => 'UPC-A',
      };

  /// Full printed code length, check digit included.
  int get digitLength => switch (this) {
        SushiBarcodeType.ean13 => 13,
        SushiBarcodeType.upcA => 12,
      };

  /// What the user actually types — one digit short of [digitLength]. The
  /// check digit is always computed and appended automatically when the
  /// barcode is generated (see [codec]'s `.make()` call in the renderer);
  /// the user never types or sees it as something to get right themselves.
  int get payloadLength => digitLength - 1;

  bc.Barcode get codec => switch (this) {
        SushiBarcodeType.ean13 => bc.Barcode.ean13(),
        SushiBarcodeType.upcA => bc.Barcode.upcA(),
      };

  /// Null when [value] is a valid payload (the right length, digits only)
  /// for this type; otherwise a user-facing reason it isn't. Never
  /// truncates or otherwise modifies [value] — callers always see exactly
  /// what the user typed, just told whether it's usable. The check digit
  /// is never part of [value] — there's nothing to validate a checksum
  /// against, since it's generated, not typed.
  String? validate(String value) {
    if (value.isEmpty) return 'Enter a barcode value.';
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Barcode value must contain digits only.';
    }
    if (value.length != payloadLength) {
      return '$label requires exactly $payloadLength digits — the check digit is added automatically.';
    }
    return null;
  }

  bool isValid(String value) => validate(value) == null;
}
