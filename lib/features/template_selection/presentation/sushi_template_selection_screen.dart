import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/network_error.dart';
import '../../label_printing/data/sushi_label_preset_repository.dart';
import '../../label_printing/domain/sushi_barcode.dart';
import '../../label_printing/presentation/label_print_controller.dart';
import '../../label_printing/presentation/sushi_preset_controller.dart';

/// Step in the printing flow for the Sushi Template Label: pick a saved
/// preset (or start a new one) before the print page. Mirrors
/// [FoodSelectionScreen]'s shape (search box, grid, "+" to create) but
/// against [sushiPresetControllerProvider] instead of the food catalog.
class SushiTemplateSelectionScreen extends ConsumerWidget {
  const SushiTemplateSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(filteredSushiPresetsProvider);
    final loaded = ref.watch(sushiPresetLoadedProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/templates'),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Select Sushi Template',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _startNew(context, ref),
                    icon: const Icon(Icons.add),
                    tooltip: 'Create new',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                onChanged: (value) =>
                    ref.read(sushiPresetSearchQueryProvider.notifier).state = value,
                decoration: InputDecoration(
                  hintText: 'Search Sushi Template...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
            ),
            Expanded(
              child: !loaded
                  ? const Center(child: CircularProgressIndicator())
                  : presets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'No saved sushi templates yet',
                                style: TextStyle(color: Colors.black45, fontSize: 14),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: () => _startNew(context, ref),
                                icon: const Icon(Icons.add),
                                label: const Text('Create new'),
                              ),
                            ],
                          ),
                        )
                      : _BarcodeTypeColumns(
                          presets: presets,
                          onSelect: (preset) => _selectPreset(context, ref, preset),
                          onRename: (preset) => _rename(context, ref, preset),
                          onDuplicate: (preset) => _duplicate(context, ref, preset),
                          onDelete: (preset) => _delete(context, ref, preset),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _startNew(BuildContext context, WidgetRef ref) {
    ref.read(labelPrintControllerProvider.notifier).startSushiLabel();
    context.push('/print');
  }

  void _selectPreset(BuildContext context, WidgetRef ref, SushiLabelPreset preset) {
    ref.read(labelPrintControllerProvider.notifier).startSushiLabel(preset: preset);
    context.push('/print');
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, SushiLabelPreset preset) async {
    var entered = preset.name;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Template'),
          content: TextFormField(
            autofocus: true,
            initialValue: preset.name,
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
    if (result == null || result.trim().isEmpty || !context.mounted) return;

    await _withNetworkGuard(
      context,
      () => ref
          .read(sushiPresetControllerProvider.notifier)
          .renamePreset(preset, result.trim()),
    );
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref, SushiLabelPreset preset) async {
    await _withNetworkGuard(
      context,
      () => ref
          .read(sushiPresetControllerProvider.notifier)
          .copyPreset(preset, '${preset.name} Copy'),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SushiLabelPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Template?'),
          content: Text('Are you sure you want to delete "${preset.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    await _withNetworkGuard(
      context,
      () => ref.read(sushiPresetControllerProvider.notifier).deletePreset(preset.id),
    );
  }

  Future<void> _withNetworkGuard(BuildContext context, Future<void> Function() action) async {
    if (!await hasNetworkConnection()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please check your internet connection.')),
        );
      }
      return;
    }
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
      }
    }
  }
}

/// Two columns, one per [SushiBarcodeType] — EAN-13 on the left, UPC-A on
/// the right — so the barcode type a preset is saved under is visible at
/// a glance without opening it.
class _BarcodeTypeColumns extends StatelessWidget {
  const _BarcodeTypeColumns({
    required this.presets,
    required this.onSelect,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  final List<SushiLabelPreset> presets;
  final void Function(SushiLabelPreset preset) onSelect;
  final void Function(SushiLabelPreset preset) onRename;
  final void Function(SushiLabelPreset preset) onDuplicate;
  final void Function(SushiLabelPreset preset) onDelete;

  // Reuses two swatches from the food category palette
  // (food_selection_screen.dart) for visual consistency with the rest of
  // the app, rather than introducing new one-off colors.
  static const _ean13Color = Color(0xFF1971C2); // Blue
  static const _upcAColor = Color(0xFF9C36B5); // Purple

  @override
  Widget build(BuildContext context) {
    final ean13 = presets.where((p) => p.barcodeType == SushiBarcodeType.ean13).toList();
    final upcA = presets.where((p) => p.barcodeType == SushiBarcodeType.upcA).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _BarcodeTypeColumn(
              title: 'EAN-13',
              color: _ean13Color,
              presets: ean13,
              onSelect: onSelect,
              onRename: onRename,
              onDuplicate: onDuplicate,
              onDelete: onDelete,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _BarcodeTypeColumn(
              title: 'UPC-A',
              color: _upcAColor,
              presets: upcA,
              onSelect: onSelect,
              onRename: onRename,
              onDuplicate: onDuplicate,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeTypeColumn extends StatelessWidget {
  const _BarcodeTypeColumn({
    required this.title,
    required this.color,
    required this.presets,
    required this.onSelect,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  final String title;
  final Color color;
  final List<SushiLabelPreset> presets;
  final void Function(SushiLabelPreset preset) onSelect;
  final void Function(SushiLabelPreset preset) onRename;
  final void Function(SushiLabelPreset preset) onDuplicate;
  final void Function(SushiLabelPreset preset) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              '(${presets.length})',
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (presets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'None saved',
              style: TextStyle(fontSize: 12, color: Colors.black38),
            ),
          )
        else
          for (final preset in presets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PresetTile(
                preset: preset,
                color: color,
                onSelect: () => onSelect(preset),
                onRename: () => onRename(preset),
                onDuplicate: () => onDuplicate(preset),
                onDelete: () => onDelete(preset),
              ),
            ),
      ],
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.color,
    required this.onSelect,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  final SushiLabelPreset preset;
  final Color color;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          // A colored left edge matching the column's accent color, so a
          // preset's barcode type is still visible even on its own.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Row(
            children: [
              Icon(Icons.bookmark_outline, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      preset.productTitle,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_PresetAction>(
                icon: const Icon(Icons.more_vert, size: 18),
                tooltip: 'Template options',
                onSelected: (action) => switch (action) {
                  _PresetAction.rename => onRename(),
                  _PresetAction.duplicate => onDuplicate(),
                  _PresetAction.delete => onDelete(),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: _PresetAction.rename, child: Text('Rename')),
                  PopupMenuItem(value: _PresetAction.duplicate, child: Text('Duplicate')),
                  PopupMenuItem(value: _PresetAction.delete, child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PresetAction { rename, duplicate, delete }
