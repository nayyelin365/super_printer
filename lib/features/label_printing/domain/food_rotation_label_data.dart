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
  }) {
    return FoodRotationLabelData(
      foodName: foodName ?? this.foodName,
      prepDateTime: prepDateTime ?? this.prepDateTime,
      useBy: useBy ?? this.useBy,
      employee: employee ?? this.employee,
      ph: ph ?? this.ph,
      showPh: showPh ?? this.showPh,
    );
  }
}
