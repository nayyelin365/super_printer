import 'package:flutter/material.dart';

/// A food/menu item in the catalog, optionally carrying saved Food Rotation
/// label settings (hours until use-by, employee, pH) from the last time
/// someone hit Save on the print page for it — so picking the same food
/// again later pre-fills those instead of the bare defaults.
class FoodModel {
  const FoodModel({
    required this.name,
    this.useByHours,
    this.useByMode,
    this.useByAt,
    this.employee,
    this.ph,
    this.color,
    this.targetTemperature,
  });

  final String name;
  final int? useByHours;

  /// Saved Use By format for Food Rotation labels — `'hours'` (type a
  /// number of hours) or `'dateTime'` (pick a date & time), matching
  /// `UseByMode.name`. Kept as a plain string so this domain file doesn't
  /// depend on the label-printing feature.
  final String? useByMode;

  /// The exact Use By date & time saved while [useByMode] is `'dateTime'`,
  /// so reopening the food shows that same date & time rather than an
  /// hours-based recalculation. Null in hours mode.
  final DateTime? useByAt;
  final String? employee;
  final String? ph;

  /// Category color picked when the food was added — shown as the card's
  /// accent so foods in the same category are easy to spot at a glance.
  /// Null means uncategorized (card falls back to a neutral look).
  final Color? color;

  /// Target storage/holding temperature in °F, set when the food was
  /// added — optional, shown on the card when present (e.g. "Target
  /// Tempt : 32°F").
  final double? targetTemperature;

  FoodModel copyWith({
    int? Function()? useByHours,
    String? Function()? useByMode,
    DateTime? Function()? useByAt,
    String? Function()? employee,
    String? Function()? ph,
    Color? Function()? color,
    double? Function()? targetTemperature,
  }) {
    return FoodModel(
      name: name,
      useByHours: useByHours != null ? useByHours() : this.useByHours,
      useByMode: useByMode != null ? useByMode() : this.useByMode,
      useByAt: useByAt != null ? useByAt() : this.useByAt,
      employee: employee != null ? employee() : this.employee,
      ph: ph != null ? ph() : this.ph,
      color: color != null ? color() : this.color,
      targetTemperature:
          targetTemperature != null ? targetTemperature() : this.targetTemperature,
    );
  }

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    return FoodModel(
      name: json['name'] as String,
      useByHours: json['useByHours'] as int?,
      useByMode: json['useByMode'] as String?,
      useByAt: json['useByAtMillis'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['useByAtMillis'] as int)
          : null,
      employee: json['employee'] as String?,
      ph: json['ph'] as String?,
      color: json['color'] != null ? Color(json['color'] as int) : null,
      targetTemperature: (json['targetTemperature'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (useByHours != null) 'useByHours': useByHours,
      if (useByMode != null) 'useByMode': useByMode,
      if (useByAt != null) 'useByAtMillis': useByAt!.millisecondsSinceEpoch,
      if (employee != null) 'employee': employee,
      if (ph != null) 'ph': ph,
      if (color != null) 'color': color!.toARGB32(),
      if (targetTemperature != null) 'targetTemperature': targetTemperature,
    };
  }
}

/// The default food catalog, seeded into Firestore once (see
/// `FoodCatalogRepository.ensureSeeded`) the first time the shared
/// `food_catalog` collection is empty.
///
/// This is intentionally the only place that knows the catalog's starting
/// contents. Screens and controllers only ever depend on
/// [foodCatalogProvider] (see `food_selection_controller.dart`), so where
/// the live data actually comes from (Firestore, previously on-device
/// `SharedPreferences`) never touches any UI code.
class FoodCatalog {
  const FoodCatalog._();

  static const List<FoodModel> breakfastMenu = [];
}
