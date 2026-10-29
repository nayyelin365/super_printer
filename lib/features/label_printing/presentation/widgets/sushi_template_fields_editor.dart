import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/network_error.dart';
import '../../domain/sushi_barcode.dart';
import '../../domain/sushi_template_label_data.dart';
import '../label_print_controller.dart';
import '../sushi_preset_controller.dart';

/// Editable fields for the "Sushi Template Label" template, shown under
/// the live preview: label properties, then barcode settings. Preset
/// selection itself happens on the dedicated Select Sushi Template screen
/// before this page is reached — this widget only handles Save/Save As
/// New/Rename for whichever preset (if any) is currently bound (see
/// [LabelPrintState.activeSushiPresetId]).
class SushiTemplateFieldsEditor extends ConsumerWidget {
  const SushiTemplateFieldsEditor({super.key});

  static final _dateFormat = DateFormat('MM/dd/yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labelPrintControllerProvider);
    final controller = ref.read(labelPrintControllerProvider.notifier);
    final data = state.labelData as SushiTemplateLabelData;
    final barcodeError = data.barcodeType.validate(data.barcodeValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PresetRow(state: state),
        const SizedBox(height: 18),

        const _SectionLabel('LABEL PROPERTIES'),
        TextFormField(
          key: ValueKey('sushi-title-${state.formGeneration}'),
          initialValue: data.productTitle,
          decoration: const InputDecoration(labelText: 'Product Title'),
          onChanged: controller.updateSushiProductTitle,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('sushi-cooked-${state.formGeneration}'),
          initialValue: data.fullyCookedText,
          decoration: const InputDecoration(labelText: 'Fully Cooked Text'),
          onChanged: controller.updateSushiFullyCookedText,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('sushi-netweight-${state.formGeneration}'),
          initialValue: data.netWeightText,
          decoration: const InputDecoration(labelText: 'Net Weight'),
          onChanged: controller.updateSushiNetWeightText,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('sushi-price-${state.formGeneration}'),
          initialValue: data.price.toStringAsFixed(2),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price', prefixText: '\$ '),
          onChanged: (value) {
            final parsed = double.tryParse(value);
            if (parsed != null) controller.updateSushiPrice(parsed);
          },
        ),
        const SizedBox(height: 16),

        _SellThroughField(
          fieldKey: 'sushi-bestifuselabel-${state.formGeneration}',
          labelValue: data.bestIfUseByLabel,
          onLabelChanged: controller.updateSushiBestIfUseByLabel,
          daysFieldKey: 'sushi-bestifusedays-${state.formGeneration}',
          sellThroughAt: data.bestIfUseByAt,
          dateFormat: _dateFormat,
          onDaysChanged: controller.updateSushiBestIfUseByDays,
        ),
        const SizedBox(height: 16),

        TextFormField(
          key: ValueKey('sushi-roll-${state.formGeneration}'),
          initialValue: data.rollDescription,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Roll Description'),
          onChanged: controller.updateSushiRollDescription,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('sushi-topping-${state.formGeneration}'),
          initialValue: data.topDescription,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Topping Description'),
          onChanged: controller.updateSushiTopDescription,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('sushi-ingredients-${state.formGeneration}'),
          initialValue: data.ingredientsText,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Ingredients'),
          onChanged: controller.updateSushiIngredientsText,
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SushiTemplateLabelData.madeFreshDailyText,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54),
              ),
              SizedBox(height: 4),
              Text(
                SushiTemplateLabelData.readyToEatText,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54),
              ),
              SizedBox(height: 4),
              Text(
                SushiTemplateLabelData.perishableText,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54),
              ),
              SizedBox(height: 4),
              Text(
                SushiTemplateLabelData.eatSameDayText,
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        const _SectionLabel('BARCODE SETTINGS'),
        SegmentedButton<SushiBarcodeType>(
          segments: const [
            ButtonSegment(value: SushiBarcodeType.ean13, label: Text('EAN-13')),
            ButtonSegment(value: SushiBarcodeType.upcA, label: Text('UPC-A')),
          ],
          selected: {data.barcodeType},
          onSelectionChanged: (selection) =>
              controller.updateSushiBarcodeType(selection.first),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey('sushi-barcode-${state.formGeneration}'),
          initialValue: data.barcodeValue,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Barcode Value',
            helperText:
                '${data.barcodeType.payloadLength} digits — the check digit is added automatically',
            errorText: barcodeError,
          ),
          onChanged: controller.updateSushiBarcodeValue,
        ),
      ],
    );
  }
}

class _PresetRow extends ConsumerWidget {
  const _PresetRow({required this.state});
  final LabelPrintState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Two rows rather than one — packing the name and both buttons into a
    // single Row let a longer preset name squeeze the buttons so far they
    // could clip out of view entirely on a narrower panel (reported as
    // the buttons "missing sometimes"). Splitting them, and making Save/
    // Save As New full-width filled buttons instead of small TextButtons,
    // means they're always visible and unmistakably tappable.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_outline, size: 18, color: Colors.black45),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.activeSushiPresetName ?? 'Unsaved template',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _save(context, ref),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveAsNew(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Save As New'),
                  // Matches ElevatedButton's app-wide theme (vertical: 16
                  // padding) explicitly — there's no OutlinedButtonTheme,
                  // so without this it defaults shorter than Save.
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final presetId = state.activeSushiPresetId;
    if (presetId == null) {
      await _saveAsNew(context, ref);
      return;
    }
    final data = state.labelData as SushiTemplateLabelData;
    await _runSave(
      context,
      ref,
      () => ref.read(sushiPresetControllerProvider.notifier).updateFromLabelData(
            presetId,
            state.activeSushiPresetName ?? 'Untitled',
            data,
          ),
      successMessage: 'Saved "${state.activeSushiPresetName}".',
    );
  }

  Future<void> _saveAsNew(BuildContext context, WidgetRef ref) async {
    final name = await _promptForName(context, title: 'Save As New Template');
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final data = state.labelData as SushiTemplateLabelData;

    await _runSave(context, ref, () async {
      final preset = await ref
          .read(sushiPresetControllerProvider.notifier)
          .createFromLabelData(name.trim(), data);
      ref
          .read(labelPrintControllerProvider.notifier)
          .bindSushiPreset(id: preset.id, name: preset.name);
    }, successMessage: 'Saved as "$name".');
  }

  Future<void> _runSave(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (!await hasNetworkConnection()) {
      if (context.mounted) _showSnack(context, 'Network error. Please check your internet connection.');
      return;
    }
    try {
      await action();
      if (context.mounted) await _showSuccessDialog(context, successMessage);
    } catch (error) {
      if (context.mounted) _showSnack(context, networkAwareErrorMessage(error));
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSuccessDialog(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppTheme.success, size: 32),
          title: const Text('Saved'),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _promptForName(BuildContext context, {required String title}) {
    var entered = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextFormField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Template name'),
            onChanged: (value) => entered = value,
            onFieldSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(entered),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

/// Sell Through's label text, plus a plain "days from today" number box
/// (no date/time picker) — typing `2` sets Sell Through to today + 2 days,
/// shown date-only (no time) right below for confirmation.
class _SellThroughField extends StatelessWidget {
  const _SellThroughField({
    required this.fieldKey,
    required this.labelValue,
    required this.onLabelChanged,
    required this.daysFieldKey,
    required this.sellThroughAt,
    required this.dateFormat,
    required this.onDaysChanged,
  });

  final String fieldKey;
  final String labelValue;
  final ValueChanged<String> onLabelChanged;
  final String daysFieldKey;
  final DateTime sellThroughAt;
  final DateFormat dateFormat;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDays = sellThroughAt.difference(today).inDays.clamp(0, 1 << 30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: ValueKey(fieldKey),
          initialValue: labelValue,
          decoration: const InputDecoration(labelText: 'Sell Through — label'),
          onChanged: onLabelChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey(daysFieldKey),
          initialValue: '$initialDays',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Days until Sell Through',
            hintText: 'e.g. 2',
            suffixText: 'days from today',
          ),
          onChanged: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null) onDaysChanged(parsed);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Sell Through: ${dateFormat.format(sellThroughAt)}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.black45,
        ),
      ),
    );
  }
}
