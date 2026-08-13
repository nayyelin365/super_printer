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
    this.barcode = '029810801500',
  });

  final String productName;
  final String productType;
  final double? netWeight;
  final double? pricePerLb;
  final double totalAmount;
  final DateTime packedAt;
  final DateTime useBy;
  final String barcode;

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
    String? barcode,
  }) {
    return LabelData(
      productName: productName ?? this.productName,
      productType: productType ?? this.productType,
      netWeight: netWeight != null ? netWeight() : this.netWeight,
      pricePerLb: pricePerLb != null ? pricePerLb() : this.pricePerLb,
      totalAmount: totalAmount ?? this.totalAmount,
      packedAt: packedAt ?? this.packedAt,
      useBy: useBy ?? this.useBy,
      barcode: barcode ?? this.barcode,
    );
  }
}
