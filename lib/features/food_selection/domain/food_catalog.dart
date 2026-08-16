/// A food/menu item in the catalog, optionally carrying saved Food Rotation
/// label settings (hours until use-by, employee, pH) from the last time
/// someone hit Save on the print page for it — so picking the same food
/// again later pre-fills those instead of the bare defaults.
class FoodModel {
  const FoodModel({
    required this.name,
    this.useByHours,
    this.employee,
    this.ph,
  });

  final String name;
  final int? useByHours;
  final String? employee;
  final String? ph;

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    return FoodModel(
      name: json['name'] as String,
      useByHours: json['useByHours'] as int?,
      employee: json['employee'] as String?,
      ph: json['ph'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (useByHours != null) 'useByHours': useByHours,
      if (employee != null) 'employee': employee,
      if (ph != null) 'ph': ph,
    };
  }
}

/// Local, in-memory food catalog.
///
/// This is intentionally the only place that knows where food data comes
/// from. Screens and controllers only ever depend on [foodCatalogProvider]
/// (see `food_selection_controller.dart`), so swapping this for an
/// API/database-backed repository later doesn't touch any UI code.
class FoodCatalog {
  const FoodCatalog._();

  static const List<FoodModel> breakfastMenu = [
    FoodModel(name: 'Classic Pancakes'),
    FoodModel(name: 'French Toast'),
    FoodModel(name: 'Belgian Waffles'),
    FoodModel(name: 'Breakfast Burrito'),
    FoodModel(name: 'Egg & Cheese Sandwich'),
  ];
}
