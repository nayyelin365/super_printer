/// Structured data for a single label. Consumed by [LabelRenderer] to
/// produce both the live preview and the final print bitmap, so the two
/// can never visually drift apart.
class LabelData {
  const LabelData({
    this.productName = 'CUSTOM POKE BOWL / BURRITO',
    this.productType = '',
    this.netWeight,
    this.pricePerLb,
    this.totalAmount = 0,
    required this.packedAt,
    required this.useBy,
    this.showBarcode = true,
  });

  /// Fixed EAN-13 prefix; the total amount (in cents) is encoded into the
  /// last 4 digits, e.g. prefix + "0800" for $8.00.
  static const String barcodePrefix = '02981080';

  final String productName;
  final String productType;
  final double? netWeight;
  final double? pricePerLb;
  final double totalAmount;
  final DateTime packedAt;
  final DateTime useBy;

  /// Whether the barcode section renders at all. When false, the renderer
  /// must not just hide the barcode in place — it reflows the remaining
  /// content to fill the freed space (see [LabelRenderer]).
  final bool showBarcode;

  /// The 12-digit EAN-13 payload (before the check digit): [barcodePrefix]
  /// with the total amount, in cents, zero-padded into the last 4 digits.
  /// Amounts above $99.99 are clamped, since only 4 digits are available.
  String get barcodeData {
    final cents = (totalAmount * 100).round().clamp(0, 9999);
    return '$barcodePrefix${cents.toString().padLeft(4, '0')}';
  }

  /// The full 13-digit EAN-13 number (payload + check digit), as printed
  /// beneath the barcode.
  String get barcodeDisplay => '$barcodeData${_ean13CheckDigit(barcodeData)}';

  /// Standard EAN/UPC modulo-10 check digit.
  static String _ean13CheckDigit(String data12) {
    var sum = 0;
    var fak = data12.length;
    for (final c in data12.codeUnits) {
      sum += fak.isEven ? (c - 0x30) : (c - 0x30) * 3;
      fak--;
    }
    final rem = sum % 10;
    return rem == 0 ? '0' : (10 - rem).toString();
  }

  static LabelData initial() {
    final now = DateTime.now();
    return LabelData(
      packedAt: now,
      useBy: now.add(const Duration(days: 3)),
    );
  }

  LabelData copyWith({
    String? productName,
    String? productType,
    double? Function()? netWeight,
    double? Function()? pricePerLb,
    double? totalAmount,
    DateTime? packedAt,
    DateTime? useBy,
    bool? showBarcode,
  }) {
    return LabelData(
      productName: productName ?? this.productName,
      productType: productType ?? this.productType,
      netWeight: netWeight != null ? netWeight() : this.netWeight,
      pricePerLb: pricePerLb != null ? pricePerLb() : this.pricePerLb,
      totalAmount: totalAmount ?? this.totalAmount,
      packedAt: packedAt ?? this.packedAt,
      useBy: useBy ?? this.useBy,
      showBarcode: showBarcode ?? this.showBarcode,
    );
  }
}
