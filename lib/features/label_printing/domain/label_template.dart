import 'label_component.dart';

/// Coarse category used to pick a renderer and a [LabelData] shape. Built-in
/// templates each get their own bespoke renderer/data class; every custom
/// template — no matter how many a user creates — shares the single
/// `custom` renderer/data path, driven entirely by [LabelTemplate.components].
enum LabelTemplateType { pokeBowlBurrito, foodRotation, custom }

/// A label template: built-in (fixed layout, code-defined) or custom
/// (user-defined, JSON-serializable, persisted locally). This is the one
/// model that drives Template Selection, the Template Builder, and the
/// print page — there is no separate "template metadata" vs "template
/// definition" split.
class LabelTemplate {
  const LabelTemplate({
    required this.id,
    required this.name,
    this.description = '',
    required this.type,
    this.widthInches = 3,
    this.heightInches = 2,
    this.dpi = 300,
    this.components = const [],
    required this.isBuiltIn,
    required this.requiresFoodSelection,
    this.supportsBarcode = false,
  });

  final String id;
  final String name;
  final String description;
  final LabelTemplateType type;

  final double widthInches;
  final double heightInches;
  final int dpi;

  /// Empty for built-in templates (they render from fixed, code-defined
  /// layouts); populated for custom templates.
  final List<LabelComponent> components;

  final bool isBuiltIn;

  /// Whether choosing this template routes through Food Selection before
  /// the print page, or goes straight to the print page.
  final bool requiresFoodSelection;

  /// Built-ins only: whether the fixed layout has a barcode section at
  /// all. Custom templates instead just have (or don't have) a `barcode`
  /// component in [components].
  final bool supportsBarcode;

  LabelTemplate copyWith({
    String? name,
    String? description,
    List<LabelComponent>? components,
    bool? requiresFoodSelection,
  }) {
    return LabelTemplate(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type,
      widthInches: widthInches,
      heightInches: heightInches,
      dpi: dpi,
      components: components ?? this.components,
      isBuiltIn: isBuiltIn,
      requiresFoodSelection: requiresFoodSelection ?? this.requiresFoodSelection,
      supportsBarcode: supportsBarcode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type.name,
        'widthInches': widthInches,
        'heightInches': heightInches,
        'dpi': dpi,
        'components': components.map((c) => c.toJson()).toList(),
        'isBuiltIn': isBuiltIn,
        'requiresFoodSelection': requiresFoodSelection,
        'supportsBarcode': supportsBarcode,
      };

  factory LabelTemplate.fromJson(Map<String, dynamic> json) {
    return LabelTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: LabelTemplateType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => LabelTemplateType.custom,
      ),
      widthInches: (json['widthInches'] as num?)?.toDouble() ?? 3,
      heightInches: (json['heightInches'] as num?)?.toDouble() ?? 2,
      dpi: json['dpi'] as int? ?? 300,
      components: (json['components'] as List<dynamic>? ?? [])
          .map((c) => LabelComponent.fromJson(c as Map<String, dynamic>))
          .toList(),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      requiresFoodSelection: json['requiresFoodSelection'] as bool? ?? false,
      supportsBarcode: json['supportsBarcode'] as bool? ?? false,
    );
  }
}

/// The two built-in templates. Not persisted, not editable, not
/// deletable — see [LabelTemplate.isBuiltIn].
class LabelTemplateCatalog {
  const LabelTemplateCatalog._();

  static const pokeBowlBurrito = LabelTemplate(
    id: 'builtin_poke_bowl_burrito',
    type: LabelTemplateType.pokeBowlBurrito,
    name: 'Custom Poke Bowl / Burrito',
    description: 'Poke bowl and burrito label',
    isBuiltIn: true,
    requiresFoodSelection: false,
    supportsBarcode: true,
  );

  static const foodRotation = LabelTemplate(
    id: 'builtin_food_rotation',
    type: LabelTemplateType.foodRotation,
    name: 'Food Rotation Label',
    description: 'Food preparation and rotation label',
    isBuiltIn: true,
    requiresFoodSelection: true,
    supportsBarcode: false,
  );

  static const List<LabelTemplate> builtIns = [pokeBowlBurrito, foodRotation];
}
