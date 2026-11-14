import 'label_data.dart';
import 'label_template.dart';

/// Label data for the "Food Rotation Label" template: prep/use-by tracking
/// for kitchen food rotation, with no weight/price/barcode fields at all —
/// those are specific to [PokeBowlLabelData] and never leak in here.
class FoodRotationLabelData extends LabelData {
  const FoodRotationLabelData({
    this.foodName = '',
    required this.prepDateTime,
    required this.useBy,
    this.employee = '',
    this.ph = '',
    this.showPh = false,
    this.ingredientsText = '',
    this.showIngredients = false,
  });

  final String foodName;
  final DateTime prepDateTime;
  @override
  final DateTime useBy;
  final String employee;

  /// Optional pH reading. Hidden by default — like
  /// [PokeBowlLabelData.showBarcode], when [showPh] is false the renderer
  /// must not just hide the value in place, it must not reserve space for
  /// it either.
  final String ph;
  final bool showPh;

  /// Optional ingredients list, shown under Employee. Hidden by default —
  /// like [showPh], when false the renderer doesn't reserve space for it.
  /// When shown, the renderer also tightens the spacing of everything
  /// above it (prep date/time, the use-by box, employee) to make more
  /// room, since this is typically 3-5 lines of text.
  final String ingredientsText;
  final bool showIngredients;

  @override
  LabelTemplateType get templateType => LabelTemplateType.foodRotation;

  static FoodRotationLabelData initial() {
    final now = DateTime.now();
    return FoodRotationLabelData(
      prepDateTime: now,
      useBy: now.add(const Duration(hours: 24)),
    );
  }

  FoodRotationLabelData copyWith({
    String? foodName,
    DateTime? prepDateTime,
    DateTime? useBy,
    String? employee,
    String? ph,
    bool? showPh,
    String? ingredientsText,
    bool? showIngredients,
  }) {
    return FoodRotationLabelData(
      foodName: foodName ?? this.foodName,
      prepDateTime: prepDateTime ?? this.prepDateTime,
      useBy: useBy ?? this.useBy,
      employee: employee ?? this.employee,
      ph: ph ?? this.ph,
      showPh: showPh ?? this.showPh,
      ingredientsText: ingredientsText ?? this.ingredientsText,
      showIngredients: showIngredients ?? this.showIngredients,
    );
  }
}
