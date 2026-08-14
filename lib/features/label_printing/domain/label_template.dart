/// Identifies a label template. Adding a template means adding a new case
/// here plus an entry in [LabelTemplateCatalog] and the renderer registry —
/// nothing else in the app switches on this directly.
enum LabelTemplateType { pokeBowlBurrito, foodRotation }

/// Static configuration for a label template: what it's called, whether it
/// needs a food picked first, and which optional label features it uses.
class LabelTemplate {
  const LabelTemplate({
    required this.type,
    required this.name,
    required this.description,
    required this.requiresFoodSelection,
    required this.supportsBarcode,
  });

  final LabelTemplateType type;
  final String name;
  final String description;

  /// Whether choosing this template routes through Food Selection before
  /// the print page, or goes straight to the print page.
  final bool requiresFoodSelection;

  /// Whether this template's label has a barcode section at all.
  final bool supportsBarcode;
}

/// The set of available templates. Append here (and wire up a
/// [LabelData]/[LabelTemplateRenderer] pair) to add a new template without
/// touching template-selection or navigation logic.
class LabelTemplateCatalog {
  const LabelTemplateCatalog._();

  static const pokeBowlBurrito = LabelTemplate(
    type: LabelTemplateType.pokeBowlBurrito,
    name: 'Custom Poke Bowl / Burrito',
    description: 'Poke bowl and burrito label',
    requiresFoodSelection: false,
    supportsBarcode: true,
  );

  static const foodRotation = LabelTemplate(
    type: LabelTemplateType.foodRotation,
    name: 'Food Rotation Label',
    description: 'Food preparation and rotation label',
    requiresFoodSelection: true,
    supportsBarcode: false,
  );

  static const List<LabelTemplate> all = [pokeBowlBurrito, foodRotation];

  static LabelTemplate byType(LabelTemplateType type) =>
      all.firstWhere((t) => t.type == type);
}
