import 'package:flutter/material.dart';

/// The kinds of building blocks a custom label can be made of. Adding a new
/// kind means: a case here, a branch in [GenericLabelRenderer], and (if it
/// needs its own properties) a section in the template builder's property
/// editor — nothing else needs to change.
enum LabelComponentType { text, barcode, dateTime, divider, image }

/// The dynamic fields a component can be bound to. A component with
/// `fieldKey == null` is either static text (its literal [LabelComponent.value]
/// is always printed as-is) or a divider/image, which don't bind to data.
class LabelFieldKey {
  const LabelFieldKey._();

  static const foodName = 'foodName';
  static const netWeight = 'netWeight';
  static const price = 'price';
  static const totalAmount = 'totalAmount';
  static const packedDate = 'packedDate';
  static const packedTime = 'packedTime';
  static const useByDate = 'useByDate';
  static const useByTime = 'useByTime';
  static const employee = 'employee';
  static const barcode = 'barcode';
  static const quantity = 'quantity';

  /// Field keys offered for text/barcode components (everything except the
  /// date/time ones, which are only offered on `dateTime` components).
  static const List<String> textFields = [
    foodName,
    netWeight,
    price,
    totalAmount,
    employee,
    quantity,
  ];

  static const List<String> dateTimeFields = [
    packedDate,
    packedTime,
    useByDate,
    useByTime,
  ];

  static const List<String> barcodeFields = [barcode];

  static String label(String key) => switch (key) {
        foodName => 'Food Name',
        netWeight => 'Net Weight',
        price => 'Price',
        totalAmount => 'Total Amount',
        packedDate => 'Packed Date',
        packedTime => 'Packed Time',
        useByDate => 'Use By Date',
        useByTime => 'Use By Time',
        employee => 'Employee',
        barcode => 'Barcode',
        quantity => 'Quantity',
        _ => 'Custom Text',
      };
}

/// A single positioned element on a custom label, in the label's own
/// logical coordinate system (see `LabelCanvas` — 900 x 600 for a 3 x 2
/// inch label at the 300 DPI design resolution). The same coordinates
/// drive the builder preview, the print-page preview, and the final print
/// bitmap, so there is never a separate "screen layout" vs "print layout".
class LabelComponent {
  const LabelComponent({
    required this.id,
    required this.type,
    this.fieldKey,
    this.value,
    this.x = 40,
    this.y = 40,
    this.width = 400,
    this.height = 50,
    this.fontSize = 24,
    this.bold = false,
    this.alignment = TextAlign.left,
    this.visible = true,
    this.dateFormatPattern = 'MM/dd/yyyy',
    this.thickness = 2,
  });

  final String id;
  final LabelComponentType type;

  /// Binds this component to a dynamic field (see [LabelFieldKey]). Null
  /// for static text, dividers, and images.
  final String? fieldKey;

  /// Literal content: the text for static text components, or the default
  /// placeholder shown before runtime data is supplied for bound ones.
  final String? value;

  final double x;
  final double y;
  final double width;
  final double height;

  final double fontSize;
  final bool bold;
  final TextAlign alignment;
  final bool visible;

  /// `dateTime` components only.
  final String dateFormatPattern;

  /// `divider` components only.
  final double thickness;

  LabelComponent copyWith({
    String? fieldKey,
    bool clearFieldKey = false,
    String? value,
    double? x,
    double? y,
    double? width,
    double? height,
    double? fontSize,
    bool? bold,
    TextAlign? alignment,
    bool? visible,
    String? dateFormatPattern,
    double? thickness,
  }) {
    return LabelComponent(
      id: id,
      type: type,
      fieldKey: clearFieldKey ? null : (fieldKey ?? this.fieldKey),
      value: value ?? this.value,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      fontSize: fontSize ?? this.fontSize,
      bold: bold ?? this.bold,
      alignment: alignment ?? this.alignment,
      visible: visible ?? this.visible,
      dateFormatPattern: dateFormatPattern ?? this.dateFormatPattern,
      thickness: thickness ?? this.thickness,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'fieldKey': fieldKey,
        'value': value,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'fontSize': fontSize,
        'bold': bold,
        'alignment': alignment.name,
        'visible': visible,
        'dateFormatPattern': dateFormatPattern,
        'thickness': thickness,
      };

  factory LabelComponent.fromJson(Map<String, dynamic> json) {
    return LabelComponent(
      id: json['id'] as String,
      type: LabelComponentType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => LabelComponentType.text,
      ),
      fieldKey: json['fieldKey'] as String?,
      value: json['value'] as String?,
      x: (json['x'] as num?)?.toDouble() ?? 40,
      y: (json['y'] as num?)?.toDouble() ?? 40,
      width: (json['width'] as num?)?.toDouble() ?? 400,
      height: (json['height'] as num?)?.toDouble() ?? 50,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24,
      bold: json['bold'] as bool? ?? false,
      alignment: TextAlign.values.firstWhere(
        (a) => a.name == json['alignment'],
        orElse: () => TextAlign.left,
      ),
      visible: json['visible'] as bool? ?? true,
      dateFormatPattern: json['dateFormatPattern'] as String? ?? 'MM/dd/yyyy',
      thickness: (json['thickness'] as num?)?.toDouble() ?? 2,
    );
  }
}
