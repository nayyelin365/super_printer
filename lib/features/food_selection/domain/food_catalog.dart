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
    'Egg & Cheese Sandwich',
    'Bacon & Egg Sandwich',
    'Sausage Breakfast Sandwich',
    'Avocado Toast',
    'Eggs Benedict',
    'Scrambled Eggs & Toast',
    'Sunny Side Up Eggs',
    'Omelette',
    'Ham & Cheese Omelette',
    'Vegetable Omelette',
    'Breakfast Quesadilla',
    'Breakfast Bowl',
    'Yogurt & Granola',
    'Fresh Fruit Bowl',
    'Breakfast Oatmeal',
    'Overnight Oats',
    'Breakfast Bagel',
    'Cream Cheese Bagel',
    'Sausage & Egg Bowl',
    'Bacon & Egg Bowl',
    'Hash Brown Breakfast Plate',
    'Chicken & Waffles',
    'English Muffin Breakfast',
    'Peanut Butter Banana Toast',
    'Breakfast Croissant',
    'Spinach & Cheese Frittata',
  ];
}
