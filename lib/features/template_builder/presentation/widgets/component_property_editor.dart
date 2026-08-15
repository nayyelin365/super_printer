import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../label_printing/domain/label_component.dart';
import '../template_builder_controller.dart';

/// Editor for whichever component is currently selected in [ComponentList].
/// Every change updates the draft template immediately, so the preview
/// reflects it live.
class ComponentPropertyEditor extends ConsumerWidget {
  const ComponentPropertyEditor({super.key});

  static const _customTextOption = '__custom_text__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(templateBuilderControllerProvider);
    final controller = ref.read(templateBuilderControllerProvider.notifier);
    final component = state.selectedComponent;

    if (component == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Select a component to edit its properties.',
          style: TextStyle(fontSize: 12, color: Colors.black45),
        ),
      );
    }

    void update(LabelComponent Function(LabelComponent) fn) =>
        controller.updateSelectedComponent(fn);

    final fieldKeyOptions = switch (component.type) {
      LabelComponentType.text => LabelFieldKey.textFields,
      LabelComponentType.dateTime => LabelFieldKey.dateTimeFields,
      LabelComponentType.barcode => LabelFieldKey.barcodeFields,
      _ => const <String>[],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fieldKeyOptions.isNotEmpty || component.type == LabelComponentType.text) ...[
          const _Label('Content'),
          DropdownButtonFormField<String>(
            key: ValueKey('content-${component.id}'),
            initialValue: component.fieldKey ?? _customTextOption,
            items: [
              if (component.type == LabelComponentType.text)
                const DropdownMenuItem(value: _customTextOption, child: Text('Custom Text')),
              for (final key in fieldKeyOptions)
                DropdownMenuItem(value: key, child: Text(LabelFieldKey.label(key))),
            ],
            onChanged: (value) {
              if (value == null) return;
              if (value == _customTextOption) {
                update((c) => c.copyWith(clearFieldKey: true, value: c.value ?? 'Custom Text'));
              } else {
                update((c) => c.copyWith(fieldKey: value));
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        if (component.fieldKey == null && component.type != LabelComponentType.divider) ...[
          const _Label('Text'),
          TextFormField(
            key: ValueKey('value-${component.id}'),
            initialValue: component.value ?? '',
            decoration: const InputDecoration(hintText: 'Enter text'),
            onChanged: (value) => update((c) => c.copyWith(value: value)),
          ),
          const SizedBox(height: 12),
        ],
        if (component.type == LabelComponentType.barcode) ...[
          const _Label('Sample / Default Value'),
          TextFormField(
            key: ValueKey('barcodevalue-${component.id}'),
            initialValue: component.value ?? '',
            decoration: const InputDecoration(hintText: 'Preview value, e.g. 0123456789'),
            onChanged: (value) => update((c) => c.copyWith(value: value)),
          ),
          const SizedBox(height: 12),
        ],
        if (component.type == LabelComponentType.text || component.type == LabelComponentType.dateTime) ...[
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  fieldId: '${component.id}-fontSize',
                  label: 'Font Size',
                  value: component.fontSize,
                  onChanged: (v) => update((c) => c.copyWith(fontSize: v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const Text('Bold', style: TextStyle(fontSize: 13)),
                    Switch(
                      value: component.bold,
                      onChanged: (v) => update((c) => c.copyWith(bold: v)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _Label('Alignment'),
          DropdownButtonFormField<TextAlign>(
            key: ValueKey('alignment-${component.id}'),
            initialValue: component.alignment,
            items: const [
              DropdownMenuItem(value: TextAlign.left, child: Text('Left')),
              DropdownMenuItem(value: TextAlign.center, child: Text('Center')),
              DropdownMenuItem(value: TextAlign.right, child: Text('Right')),
            ],
            onChanged: (value) {
              if (value != null) update((c) => c.copyWith(alignment: value));
            },
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: _NumberField(
                fieldId: '${component.id}-x',
                label: 'X',
                value: component.x,
                onChanged: (v) => update((c) => c.copyWith(x: v)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                fieldId: '${component.id}-y',
                label: 'Y',
                value: component.y,
                onChanged: (v) => update((c) => c.copyWith(y: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                fieldId: '${component.id}-width',
                label: 'Width',
                value: component.width,
                onChanged: (v) => update((c) => c.copyWith(width: v)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                fieldId: '${component.id}-height',
                label: component.type == LabelComponentType.divider ? 'Thickness' : 'Height',
                value: component.type == LabelComponentType.divider
                    ? component.thickness
                    : component.height,
                onChanged: (v) => component.type == LabelComponentType.divider
                    ? update((c) => c.copyWith(thickness: v))
                    : update((c) => c.copyWith(height: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Visible', style: TextStyle(fontSize: 13)),
            Switch(
              value: component.visible,
              onChanged: (v) => update((c) => c.copyWith(visible: v)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.fieldId,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// Stable across keystrokes (unlike [value]) so the field never loses
  /// focus/cursor position while the user is typing; changes only when the
  /// selected component itself changes.
  final String fieldId;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey(fieldId),
      initialValue: value.toStringAsFixed(0),
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (text) {
        final parsed = double.tryParse(text);
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}
