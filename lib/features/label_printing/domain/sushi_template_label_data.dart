import 'label_data.dart';
import 'label_template.dart';
import 'sushi_barcode.dart';

/// Label data for the "Sushi Template Label" (3 x 6 in) built-in template.
///
/// [perishableText]/[eatSameDayText] are fixed compliance lines the spec
/// requires on every label but never lets the user edit — kept as static
/// consts here rather than fields, so there's nothing for the UI/Firestore
/// layer to accidentally make editable or persist per-template.
class SushiTemplateLabelData extends LabelData {
  const SushiTemplateLabelData({
    this.productTitle = 'SUSHI - CALIFORNIA ROLL',
    this.fullyCookedText = 'FULLY COOKED',
    this.netWeightText = 'Net Wt: 8.5 oz (241 g)',
    this.bestIfUseByLabel = 'Sell Through',
    required this.bestIfUseByAt,
    this.processedOnLabel = 'Processed On',
    required this.processedOnAt,
    this.price = 9.99,
    this.rollDescription =
        'ROLL: IMITATION CRAB, AVOCADO, CUCUMBER, ROASTED SEAWEED, SEASONED RICE, SESAME SEEDS.',
    this.topDescription =
        'TOPPING: IMITATION CRAB SALAD, FRIED ONION, SPICY SAUCE, TEMPURA CRUNCH, JAPANESE CHILI POWDER MIXED, GREEN ONION',
    this.ingredientsText =
        'INGREDIENTS: IMITATION CRAB, AVOCADO, CUCUMBER, ROASTED SEAWEED, SEASONED RICE, SESAME SEEDS, FRIED ONION, SPICY SAUCE, TEMPURA CRUNCH, JAPANESE CHILI POWDER, GREEN ONION.',
    this.barcodeType = SushiBarcodeType.ean13,
    // 12-digit payload — the check digit is computed and appended
    // automatically, never typed (see SushiBarcodeType.payloadLength).
    this.barcodeValue = '400638133393',
  });

  static const String madeFreshDailyText = 'MADE FRESH DAILY';
  static const String readyToEatText = 'READY TO EAT';
  static const String perishableText = 'PERISHABLE: KEEP REFRIGERATED';
  static const String eatSameDayText =
      'EAT ON SAME DAY OF PURCHASED FOR BEST TASTE.';

  final String productTitle;
  final String fullyCookedText;
  final String netWeightText;
  final String bestIfUseByLabel;
  final DateTime bestIfUseByAt;
  final String processedOnLabel;
  final DateTime processedOnAt;
  final double price;
  final String rollDescription;
  final String topDescription;
  final String ingredientsText;
  final SushiBarcodeType barcodeType;
  final String barcodeValue;

  @override
  LabelTemplateType get templateType => LabelTemplateType.sushiTemplate;

  static SushiTemplateLabelData initial() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return SushiTemplateLabelData(
      bestIfUseByAt: today.add(const Duration(days: 1)),
      processedOnAt: now,
    );
  }

  SushiTemplateLabelData copyWith({
    String? productTitle,
    String? fullyCookedText,
    String? netWeightText,
    String? bestIfUseByLabel,
    DateTime? bestIfUseByAt,
    String? processedOnLabel,
    DateTime? processedOnAt,
    double? price,
    String? rollDescription,
    String? topDescription,
    String? ingredientsText,
    SushiBarcodeType? barcodeType,
    String? barcodeValue,
  }) {
    return SushiTemplateLabelData(
      productTitle: productTitle ?? this.productTitle,
      fullyCookedText: fullyCookedText ?? this.fullyCookedText,
      netWeightText: netWeightText ?? this.netWeightText,
      bestIfUseByLabel: bestIfUseByLabel ?? this.bestIfUseByLabel,
      bestIfUseByAt: bestIfUseByAt ?? this.bestIfUseByAt,
      processedOnLabel: processedOnLabel ?? this.processedOnLabel,
      processedOnAt: processedOnAt ?? this.processedOnAt,
      price: price ?? this.price,
      rollDescription: rollDescription ?? this.rollDescription,
      topDescription: topDescription ?? this.topDescription,
      ingredientsText: ingredientsText ?? this.ingredientsText,
      barcodeType: barcodeType ?? this.barcodeType,
      barcodeValue: barcodeValue ?? this.barcodeValue,
    );
  }
}
