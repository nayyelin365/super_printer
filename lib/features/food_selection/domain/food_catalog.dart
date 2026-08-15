/// Local, in-memory food catalog.
///
/// This is intentionally the only place that knows where food data comes
/// from. Screens and controllers only ever depend on [foodCatalogProvider]
/// (see `food_selection_controller.dart`), so swapping this for an
/// API/database-backed repository later doesn't touch any UI code.
class FoodCatalog {
  const FoodCatalog._();

  static const List<String> breakfastMenu = [
    'Classic Pancakes',
    'French Toast',
    'Belgian Waffles',
    'Breakfast Burrito',
    'Egg & Cheese Sandwich'
  ];
}
