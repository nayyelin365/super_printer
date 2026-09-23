import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/food_selection/data/food_catalog_repository.dart';
import 'package:super_printer/features/food_selection/domain/food_catalog.dart';
import 'package:super_printer/features/food_selection/presentation/food_selection_controller.dart';
import 'package:super_printer/features/label_printing/domain/food_rotation_label_data.dart';
import 'package:super_printer/features/label_printing/domain/label_template.dart';
import 'package:super_printer/features/label_printing/presentation/label_print_controller.dart';

void main() {
  test('Date & Time use-by is saved on the food and restored when it is reopened', () async {
    final firestore = FakeFirebaseFirestore();
    final container = ProviderContainer(overrides: [
      foodCatalogRepositoryProvider.overrideWithValue(FoodCatalogRepository(firestore: firestore)),
    ]);
    addTearDown(container.dispose);

    container.read(foodCatalogProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await container.read(foodCatalogProvider.notifier).addFood('Miso Soup');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final label = container.read(labelPrintControllerProvider.notifier);
    label.startNewLabel(LabelTemplateCatalog.foodRotation, foodName: 'Miso Soup');
    label.setUseByMode(UseByMode.dateTime);
    final picked = DateTime(2030, 1, 2, 17, 30);
    label.updateUseByDateTime(picked);
    label.saveCurrentFoodSettings();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final saved = container.read(foodCatalogProvider).firstWhere((f) => f.name == 'Miso Soup');
    expect(saved.useByMode, 'dateTime');
    expect(saved.useByAt, picked);

    label.startNewLabel(LabelTemplateCatalog.foodRotation, foodName: 'Miso Soup', food: saved);
    final state = container.read(labelPrintControllerProvider);
    expect(state.useByMode, UseByMode.dateTime);
    expect((state.labelData as FoodRotationLabelData).useBy, picked);
  });
}
