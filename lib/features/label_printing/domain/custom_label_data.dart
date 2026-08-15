import 'package:intl/intl.dart';

import 'label_component.dart';
import 'label_data.dart';
import 'label_template.dart';

/// Runtime data for any user-created (custom) template. Unlike the
/// built-in templates, a single class serves every custom template — what
/// varies is [template.components] plus whichever of [fieldValues] each one
/// is bound to. New custom templates never require a new [LabelData]
/// subclass.
class CustomLabelData extends LabelData {
  const CustomLabelData({
    required this.template,
    required this.packedAt,
    required DateTime? useByAt,
    this.fieldValues = const {},
  }) : _useByAt = useByAt;

  final LabelTemplate template;
  final DateTime packedAt;
  final DateTime? _useByAt;

  /// Raw values for every field-bound component except the packed/use-by
  /// date/time ones (those are derived from [packedAt]/[useByAt] so the Use
  /// By quick-select stays consistent, the same way the built-in templates
  /// work).
  final Map<String, String> fieldValues;

  @override
  LabelTemplateType get templateType => LabelTemplateType.custom;

  @override
  DateTime? get useBy => _useByAt;

  static final _dateFormat = DateFormat('MM/dd/yyyy');
  static final _timeFormat = DateFormat('hh:mm a');

  /// Resolves a component's display text: static value for unbound
  /// components, [packedAt]/[useByAt] for the date/time field keys, or
  /// whatever the user typed for every other dynamic field.
  String resolve(LabelComponent component) {
    final key = component.fieldKey;
    if (key == null) return component.value ?? '';
    return switch (key) {
      LabelFieldKey.packedDate => _dateFormat.format(packedAt),
      LabelFieldKey.packedTime => _timeFormat.format(packedAt),
      LabelFieldKey.useByDate => _useByAt != null ? _dateFormat.format(_useByAt) : '-',
      LabelFieldKey.useByTime => _useByAt != null ? _timeFormat.format(_useByAt) : '-',
      _ => fieldValues[key] ?? component.value ?? '',
    };
  }

  /// A fresh label for [template]: "now" as the packed time, +3 days as the
  /// use-by (only meaningful if the template actually has a use-by
  /// component, but harmless either way), and each bound component seeded
  /// from its own default [LabelComponent.value].
  static CustomLabelData initial(LabelTemplate template) {
    final now = DateTime.now();
    final values = <String, String>{};
    for (final component in template.components) {
      final key = component.fieldKey;
      if (key == null || LabelFieldKey.dateTimeFields.contains(key)) continue;
      values[key] = component.value ?? '';
    }
    final hasUseBy = template.components.any(
      (c) => c.fieldKey == LabelFieldKey.useByDate || c.fieldKey == LabelFieldKey.useByTime,
    );
    return CustomLabelData(
      template: template,
      packedAt: now,
      useByAt: hasUseBy ? now.add(const Duration(hours: 24)) : null,
      fieldValues: values,
    );
  }

  CustomLabelData copyWith({
    DateTime? packedAt,
    DateTime? Function()? useByAt,
    Map<String, String>? fieldValues,
  }) {
    return CustomLabelData(
      template: template,
      packedAt: packedAt ?? this.packedAt,
      useByAt: useByAt != null ? useByAt() : _useByAt,
      fieldValues: fieldValues ?? this.fieldValues,
    );
  }

  CustomLabelData withFieldValue(String fieldKey, String value) {
    return copyWith(fieldValues: {...fieldValues, fieldKey: value});
  }
}
