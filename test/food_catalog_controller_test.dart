import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:super_printer/features/food_selection/domain/food_catalog.dart';
import 'package:super_printer/features/food_selection/presentation/food_selection_controller.dart';

void main() {
  group('FoodCatalogController', () {
    test('seeds from FoodCatalog defaults on first run, without persisting until a real mutation',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(foodCatalogProvider), FoodCatalog.breakfastMenu);

      // Deliberately does NOT eagerly persist the seed — doing so could
      // race with (and clobber) an add/remove that runs before _restore()
      // completes. Nothing is written until a real mutation happens.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('food_catalog_items_v2'), isNull);
    });

    test('addFood appends and persists; rejects blank/duplicate (case-insensitive)', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(foodCatalogProvider.notifier);

      expect(await notifier.addFood('Loaded Waffle Bowl'), isTrue);
      expect(
        container.read(foodCatalogProvider).map((f) => f.name),
        contains('Loaded Waffle Bowl'),
      );

      expect(await notifier.addFood('  '), isFalse);
      expect(await notifier.addFood('loaded waffle bowl'), isFalse);
      expect(
        container
            .read(foodCatalogProvider)
            .where((f) => f.name == 'Loaded Waffle Bowl')
            .length,
        1,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('food_catalog_items_v2'), contains('Loaded Waffle Bowl'));
    });

    test('removeFood removes and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(foodCatalogProvider.notifier);
      await notifier.removeFood('Classic Pancakes');

      expect(
        container.read(foodCatalogProvider).map((f) => f.name),
        isNot(contains('Classic Pancakes')),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('food_catalog_items_v2'), isNot(contains('Classic Pancakes')));
    });

    test('a later container reads back a previously saved (mutated) catalog', () async {
      SharedPreferences.setMockInitialValues({});

      final firstContainer = ProviderContainer();
      await firstContainer.read(foodCatalogProvider.notifier).addFood('Custom Grits Bowl');
      await firstContainer.read(foodCatalogProvider.notifier).removeFood('French Toast');
      firstContainer.dispose();

      final secondContainer = ProviderContainer();
      addTearDown(secondContainer.dispose);
      // The first .read() lazily constructs the controller (and kicks off
      // its async _restore()); wait for that to finish before reading
      // again, otherwise this just observes the pre-restore in-memory
      // defaults.
      secondContainer.read(foodCatalogProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final restored = secondContainer.read(foodCatalogProvider).map((f) => f.name);
      expect(restored, contains('Custom Grits Bowl'));
      expect(restored, isNot(contains('French Toast')));
    });

    test('saveFoodSettings attaches hours/employee/ph to an existing entry and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(foodCatalogProvider.notifier);
      await notifier.saveFoodSettings(
        'Classic Pancakes',
        useByHours: 12,
        employee: 'JS',
        ph: '6.5',
      );

      final saved = container
          .read(foodCatalogProvider)
          .firstWhere((f) => f.name == 'Classic Pancakes');
      expect(saved.useByHours, 12);
      expect(saved.employee, 'JS');
      expect(saved.ph, '6.5');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('food_catalog_items_v2'), contains('"employee":"JS"'));
    });

    test('saveFoodSettings is a no-op for a food not in the catalog', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(foodCatalogProvider.notifier);
      final before = container.read(foodCatalogProvider);
      await notifier.saveFoodSettings('Not In Catalog', useByHours: 12);

      expect(container.read(foodCatalogProvider), before);
    });
  });
}
