import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/food_selection/domain/food_catalog.dart';

void main() {
  group('FoodModel', () {
    test('toJson/fromJson round-trip preserves every field', () {
      const food = FoodModel(
        name: 'Loaded Waffle Bowl',
        useByHours: 12,
        employee: 'JS',
        ph: '6.5',
        color: Color(0xFF2F9E44),
        targetTemperature: 34.5,
      );
      final restored = FoodModel.fromJson(food.toJson());

      expect(restored.name, food.name);
      expect(restored.useByHours, food.useByHours);
      expect(restored.employee, food.employee);
      expect(restored.ph, food.ph);
      expect(restored.color, food.color);
      expect(restored.targetTemperature, food.targetTemperature);
    });

    test('toJson omits unset optional fields entirely', () {
      const food = FoodModel(name: 'Classic Pancakes');
      final json = food.toJson();
      expect(json.keys, ['name']);
    });

    test('copyWith replaces only the given Food Rotation settings', () {
      const food = FoodModel(name: 'Belgian Waffles', useByHours: 24);
      final updated = food.copyWith(employee: () => 'NL', ph: () => '4.1');

      expect(updated.name, 'Belgian Waffles');
      expect(updated.useByHours, 24);
      expect(updated.employee, 'NL');
      expect(updated.ph, '4.1');
    });
  });
}
