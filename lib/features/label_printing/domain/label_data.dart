import 'label_template.dart';
import 'poke_bowl_pricing.dart';

/// Base type for a template's label data. Each template owns its own
/// concrete subclass with only the fields it needs — see
/// [PokeBowlLabelData] and `FoodRotationLabelData`. Nothing generic is
/// forced onto every template beyond knowing which one it is.
abstract class LabelData {
  const LabelData();

  LabelTemplateType get templateType;

  /// A use-by date, computed from whatever this template's own "start"
  /// date is (packed date, prep date/time, ...), if it has the concept at
  /// all — shared UI like the Use By selector reads this without knowing
  /// which template it is, and hides itself when null.
  DateTime? get useBy => null;
}

/// Label data for the "Custom Poke Bowl / Burrito" template (weighed deli
/// items with a price-encoded barcode).
class PokeBowlLabelData extends LabelData {
  const PokeBowlLabelData({
    this.productName = 'CUSTOM POKE BOWL / BURRITO',
    this.productType = '',
    this.basePriceLabel,
    this.basePriceAmount,
    this.extraLines = const [],
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

  /// The currently selected base price tile's name/amount (only one can be
  /// active — see `LabelPrintController.selectBasePrice`), or null if none
  /// is selected (e.g. Total Amount was typed by hand instead).
  final String? basePriceLabel;
  final double? basePriceAmount;

  /// Extra add-ons tapped on top of the base price, in the order added —
  /// the same extra can appear more than once (see
  /// `LabelPrintController.addExtraPrice`).
  final List<PokeBowlPriceLine> extraLines;

  final double totalAmount;
  final DateTime packedAt;
  @override
  final DateTime useBy;

  /// Whether the barcode section renders at all. When false, the renderer
  /// must not just hide the barcode in place — it reflows the remaining
  /// content to fill the freed space (see [PokeBowlLabelRenderer]).
  final bool showBarcode;

  @override
  LabelTemplateType get templateType => LabelTemplateType.pokeBowlBurrito;

  /// The itemized price list the label prints: the selected base price (if
  /// any) followed by every extra, in the order added.
  List<PokeBowlPriceLine> get priceLines => [
        if (basePriceLabel != null && basePriceAmount != null)
          PokeBowlPriceLine(basePriceLabel!, basePriceAmount!),
        ...extraLines,
      ];

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

  static PokeBowlLabelData initial() {
    final now = DateTime.now();
    return PokeBowlLabelData(
      packedAt: now,
      useBy: now.add(const Duration(hours: 24)),
    );
  }

  PokeBowlLabelData copyWith({
    String? productName,
    String? productType,
    String? Function()? basePriceLabel,
    double? Function()? basePriceAmount,
    List<PokeBowlPriceLine>? extraLines,
    double? totalAmount,
    DateTime? packedAt,
    DateTime? useBy,
    bool? showBarcode,
  }) {
    return PokeBowlLabelData(
      productName: productName ?? this.productName,
      productType: productType ?? this.productType,
      basePriceLabel: basePriceLabel != null ? basePriceLabel() : this.basePriceLabel,
      basePriceAmount: basePriceAmount != null ? basePriceAmount() : this.basePriceAmount,
      extraLines: extraLines ?? this.extraLines,
      totalAmount: totalAmount ?? this.totalAmount,
      packedAt: packedAt ?? this.packedAt,
      useBy: useBy ?? this.useBy,
      showBarcode: showBarcode ?? this.showBarcode,
    );
  }
}
