import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/label_printing/data/sushi_label_preset_repository.dart';
import 'package:super_printer/features/label_printing/domain/sushi_barcode.dart';
import 'package:super_printer/features/label_printing/presentation/sushi_preset_controller.dart';

void main() {
  SushiLabelPreset samplePreset() {
    final now = DateTime(2026, 7, 19, 10, 30);
    return SushiLabelPreset(
      id: 'p1',
      name: 'California Roll',
      productTitle: 'SUSHI - CALIFORNIA ROLL',
      fullyCookedText: 'FULLY COOKED',
      netWeightText: 'Net Wt: 8.5 oz (241 g)',
      bestIfUseByLabel: 'Best If Use By',
      processedOnLabel: 'Processed On',
      price: 9.99,
      rollDescription: 'ROLL: IMITATION CRAB, AVOCADO, CUCUMBER.',
      topDescription: 'TOPPING: IMITATION CRAB SALAD.',
      barcodeType: SushiBarcodeType.upcA,
      barcodeValue: '036000291452',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('SushiLabelPreset', () {
    test('toJson/fromJson round-trip preserves every field', () {
      final preset = samplePreset();
      final restored = SushiLabelPreset.fromJson(preset.id, preset.toJson());

      expect(restored.name, preset.name);
      expect(restored.productTitle, preset.productTitle);
      expect(restored.fullyCookedText, preset.fullyCookedText);
      expect(restored.netWeightText, preset.netWeightText);
      expect(restored.bestIfUseByLabel, preset.bestIfUseByLabel);
      expect(restored.processedOnLabel, preset.processedOnLabel);
      expect(restored.price, preset.price);
      expect(restored.rollDescription, preset.rollDescription);
      expect(restored.topDescription, preset.topDescription);
      expect(restored.barcodeType, SushiBarcodeType.upcA);
      expect(restored.barcodeValue, preset.barcodeValue);
      expect(restored.createdAt, preset.createdAt);
      expect(restored.updatedAt, preset.updatedAt);
    });
  });

  group('sushiLabelDataFromPreset', () {
    test('copies every text/number/barcode field but never the saved dates', () {
      final preset = samplePreset();
      final data = sushiLabelDataFromPreset(preset);

      expect(data.productTitle, preset.productTitle);
      expect(data.barcodeType, preset.barcodeType);
      expect(data.barcodeValue, preset.barcodeValue);
      expect(data.price, preset.price);

      // Best If Use By / Processed On are always fresh — never the
      // moment the preset happened to be saved (2026-07-19).
      final now = DateTime.now();
      expect(data.processedOnAt.difference(now).inMinutes.abs() < 1, isTrue);
      expect(data.bestIfUseByAt.isAfter(data.processedOnAt), isTrue);
    });
  });
}
