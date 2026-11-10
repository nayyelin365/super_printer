import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';

/// The kinds of building blocks a custom label can be made of. Adding a new
/// kind means: a case here, a branch in [GenericLabelRenderer], and (if it
/// needs its own properties) a section in the template builder's property
/// editor — nothing else needs to change.
enum LabelComponentType { text, barcode, dateTime, divider, image, box }

/// `box` components only: the outline/fill shape to draw.
enum LabelBoxShape { rectangle, oval }

/// `text`/`dateTime` components only: a curated list of Google Fonts
/// offered in the font family picker — not every Google Font, just a small
/// set covering the common style categories (sans, serif, mono, display,
/// script), since the full catalog has thousands of entries. A component's
/// `fontFamily` isn't restricted to this list (it's just a string name
/// passed to `GoogleFonts.getFont`), but this is what the UI shows.
class LabelFontFamily {
  const LabelFontFamily._();

  /// Null/absent in [LabelComponent.fontFamily] means the platform default
  /// font, not a Google Font — this is the dropdown's label for that.
  static const defaultLabel = 'Default';

  static const List<String> options = [
    // Sans-serif
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat',
    'Poppins',
    'Nunito',
    'Raleway',
    'Ubuntu',
    'Inter',
    'Rubik',
    'Work Sans',
    'Fira Sans',
    'Barlow',
    'Quicksand',
    'Noto Sans',
    // Serif
    'Playfair Display',
    'Merriweather',
    'Lora',
    'Libre Baskerville',
    'Crimson Text',
    // Monospace
    'Roboto Mono',
    'JetBrains Mono',
    'Space Mono',
    // Display / script / handwriting
    'Oswald',
    'Bebas Neue',
    'Anton',
    'Abril Fatface',
    'Caveat',
    'Pacifico',
    'Dancing Script',
    'Indie Flower',
    'Permanent Marker',
    'Shadows Into Light',
  ];
}

/// `barcode` components only: which symbology to render the value as.
/// [ean13]/[upcA] mirror the Sushi Template Label's retail-barcode handling
/// (see `sushi_barcode.dart`'s `SushiBarcodeType`) — the user types only the
/// payload (one digit short of the printed length) and the check digit is
/// computed automatically, rather than being typed.
enum BarcodeSymbology { code128, qrCode, ean13, upcA }

extension BarcodeSymbologyX on BarcodeSymbology {
  String get label => switch (this) {
        BarcodeSymbology.code128 => 'Barcode (Code 128)',
        BarcodeSymbology.qrCode => 'QR Code',
        BarcodeSymbology.ean13 => 'EAN-13',
        BarcodeSymbology.upcA => 'UPC-A',
      };

  bool get isRetail => this == BarcodeSymbology.ean13 || this == BarcodeSymbology.upcA;

  /// Full printed code length (check digit included) — [ean13]/[upcA] only.
  int get digitLength => switch (this) {
        BarcodeSymbology.ean13 => 13,
        BarcodeSymbology.upcA => 12,
        _ => 0,
      };

  /// What the user actually types for [ean13]/[upcA] — one digit short of
  /// [digitLength]; the check digit is always computed and appended
  /// automatically when the barcode is generated.
  int get payloadLength => digitLength - 1;

  bc.Barcode get codec => switch (this) {
        BarcodeSymbology.code128 => bc.Barcode.code128(),
        BarcodeSymbology.qrCode => bc.Barcode.qrCode(),
        BarcodeSymbology.ean13 => bc.Barcode.ean13(),
        BarcodeSymbology.upcA => bc.Barcode.upcA(),
      };

  /// Null when [value] is usable for this symbology; otherwise a
  /// user-facing reason it isn't. For [ean13]/[upcA], never truncates or
  /// otherwise modifies [value] — the caller always sees exactly what the
  /// user typed, just told whether it's usable; there's nothing to
  /// validate a checksum against since it's generated, not typed.
  String? validate(String value) {
    if (!isRetail) return value.trim().isEmpty ? 'Enter a value.' : null;
    if (value.isEmpty) return 'Enter a barcode value.';
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Barcode value must contain digits only.';
    }
    if (value.length != payloadLength) {
      return '$label requires exactly $payloadLength digits — the check digit is added automatically.';
    }
    return null;
  }

  bool isValid(String value) => validate(value) == null;
}

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
    this.vertical = false,
    this.barcodeSymbology = BarcodeSymbology.code128,
    this.filled = false,
    this.whiteText = false,
    this.italic = false,
    this.rotationDegrees = 0,
    this.boxShape = LabelBoxShape.rectangle,
    this.fontFamily,
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

  /// `divider` components only: draws a vertical line ([height] long,
  /// anchored at [x]/[y]) instead of the default horizontal one ([width]
  /// long).
  final bool vertical;

  /// `barcode` components only: which symbology [value] is rendered as.
  final BarcodeSymbology barcodeSymbology;

  /// `box` components only: an outline box (border only, [thickness] wide)
  /// when false, or a solid filled rectangle when true.
  final bool filled;

  /// `text`/`dateTime` components only: renders in white instead of black
  /// — for text placed on top of a filled (black) [LabelComponentType.box],
  /// where black text would be invisible.
  final bool whiteText;

  /// `text`/`dateTime` components only.
  final bool italic;

  /// `text`/`dateTime` components only: rotates the text around its box's
  /// center by this many degrees (clockwise).
  final double rotationDegrees;

  /// `box` components only.
  final LabelBoxShape boxShape;

  /// `text`/`dateTime` components only: a Google Fonts family name (see
  /// [LabelFontFamily.options]), or null for the platform default font.
  final String? fontFamily;

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
    bool? vertical,
    BarcodeSymbology? barcodeSymbology,
    bool? filled,
    bool? whiteText,
    bool? italic,
    double? rotationDegrees,
    LabelBoxShape? boxShape,
    String? fontFamily,
    bool clearFontFamily = false,
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
      vertical: vertical ?? this.vertical,
      barcodeSymbology: barcodeSymbology ?? this.barcodeSymbology,
      filled: filled ?? this.filled,
      whiteText: whiteText ?? this.whiteText,
      italic: italic ?? this.italic,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      boxShape: boxShape ?? this.boxShape,
      fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
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
        'vertical': vertical,
        'barcodeSymbology': barcodeSymbology.name,
        'filled': filled,
        'whiteText': whiteText,
        'italic': italic,
        'rotationDegrees': rotationDegrees,
        'boxShape': boxShape.name,
        'fontFamily': fontFamily,
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
      vertical: json['vertical'] as bool? ?? false,
      barcodeSymbology: BarcodeSymbology.values.firstWhere(
        (s) => s.name == json['barcodeSymbology'],
        orElse: () => BarcodeSymbology.code128,
      ),
      filled: json['filled'] as bool? ?? false,
      whiteText: json['whiteText'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0,
      boxShape: LabelBoxShape.values.firstWhere(
        (s) => s.name == json['boxShape'],
        orElse: () => LabelBoxShape.rectangle,
      ),
      fontFamily: json['fontFamily'] as String?,
    );
  }
}
