import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/network_error.dart';
import '../../label_printing/presentation/label_print_controller.dart';
import '../../template_selection/presentation/template_selection_controller.dart';
import '../domain/food_catalog.dart';
import 'food_selection_controller.dart';
import 'widgets/food_card.dart';

/// Preset swatches offered in the add-food dialog's category color picker.
const _foodCategoryColors = [
  Color(0xFFE03131),
  Color(0xFFF08C00),
  Color(0xFFF5C518),
  Color(0xFF2F9E44),
  Color(0xFF0CA678),
  Color(0xFF1971C2),
  Color(0xFF3B5BDB),
  Color(0xFF9C36B5),
  Color(0xFFE64980),
  Color(0xFF495057),
];

/// Display name for each swatch above, in the same order — used as the
/// group header when the grid is grouped by category color (e.g. "Green
/// group", "Red group").
const _foodCategoryColorNames = [
  'Red',
  'Orange',
  'Yellow',
  'Green',
  'Teal',
  'Blue',
  'Indigo',
  'Purple',
  'Pink',
  'Gray',
];

String _colorGroupName(Color color) {
  final index = _foodCategoryColors.indexOf(color);
  return index == -1 ? 'Other' : _foodCategoryColorNames[index];
}

/// Step in the printing flow for templates that need a food/menu item
/// picked first (see [LabelTemplate.requiresFoodSelection]). Selecting one
/// starts a fresh label (see [LabelPrintController.startNewLabel]) for the
/// active template, pre-filled with that name, and opens the printer
/// workspace.
///
/// The catalog itself is editable here (add via the + button, remove from
/// a card) and persisted through [FoodCatalogController] — selecting a food
/// for a label never modifies the catalog, only these explicit actions do.
class FoodSelectionScreen extends ConsumerWidget {
  const FoodSelectionScreen({super.key, this.showHeader = true});

  /// False when embedded under a host screen that already renders its own
  /// title/back/add-food chrome (see `LogHomeScreen`'s "Item Lists" tab) —
  /// avoids stacking two app bars.
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(filteredFoodsProvider);
    final loaded = ref.watch(foodCatalogLoadedProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/templates'),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Select Food',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => showAddFoodDialog(context, ref),
                      icon: const Icon(Icons.add),
                      tooltip: 'Add food',
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                onChanged: (value) =>
                    ref.read(foodSearchQueryProvider.notifier).state = value,
                decoration: InputDecoration(
                  hintText: 'Search food name...',
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
                  : foods.isEmpty
                  ? const Center(
                      child: Text(
                        'No food found',
                        style: TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                    )
                  : _GroupedFoodGrid(
                      foods: foods,
                      onSelect: (food) => _selectFood(context, ref, food),
                      onRemove: (food) =>
                          _confirmRemoveFood(context, ref, food.name),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectFood(BuildContext context, WidgetRef ref, FoodModel food) {
    final template = ref.read(selectedLabelTemplateProvider);
    ref
        .read(labelPrintControllerProvider.notifier)
        .startNewLabel(template, foodName: food.name, food: food);
    context.push('/print');
  }

  Future<void> _confirmRemoveFood(
    BuildContext context,
    WidgetRef ref,
    String food,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Food'),
          content: Text(
            'Remove "$food" from the food list? This can\'t be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(foodCatalogProvider.notifier).removeFood(food);
    }
  }
}

/// Lays [foods] out as one section per category color (e.g. "Green group",
/// "Red group") — foods with no category color are grouped last, under
/// "Uncategorized". Sections follow `_foodCategoryColors`' order, and only
/// colors actually in use get a section, so removing every food in a color
/// removes that color's section too rather than leaving it empty.
class _GroupedFoodGrid extends StatelessWidget {
  const _GroupedFoodGrid({
    required this.foods,
    required this.onSelect,
    required this.onRemove,
  });

  final List<FoodModel> foods;
  final void Function(FoodModel food) onSelect;
  final void Function(FoodModel food) onRemove;

  static const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 150,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    final groups = <(Color?, List<FoodModel>)>[];
    for (final color in _foodCategoryColors) {
      final matches = foods.where((f) => f.color == color).toList();
      if (matches.isNotEmpty) groups.add((color, matches));
    }
    // Any color a food was saved with before being removed from the preset
    // list still gets its own section rather than folding into "no color".
    final knownColors = _foodCategoryColors.toSet();
    final customColors = foods
        .map((f) => f.color)
        .whereType<Color>()
        .where((c) => !knownColors.contains(c))
        .toSet();
    for (final color in customColors) {
      groups.add((color, foods.where((f) => f.color == color).toList()));
    }
    final uncategorized = foods.where((f) => f.color == null).toList();
    if (uncategorized.isNotEmpty) groups.add((null, uncategorized));

    return CustomScrollView(
      slivers: [
        for (final group in groups) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: _GroupHeader(color: group.$1, count: group.$2.length),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: _gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final food = group.$2[index];
                  return FoodCard(
                    name: food.name,
                    color: food.color,
                    targetTemperature: food.targetTemperature,
                    onSelect: () => onSelect(food),
                    onRemove: () => onRemove(food),
                  );
                },
                childCount: group.$2.length,
              ),
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }
}

class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({required this.color, required this.count});

  final Color? color;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultLabel = color == null ? 'Uncategorized' : '${_colorGroupName(color!)} group';
    final customName =
        color == null ? null : ref.watch(foodGroupNamesProvider).valueOrNull?[color!.toARGB32()];
    final label = customName ?? defaultLabel;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color ?? AppTheme.border,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        // "Uncategorized" isn't a color group, so it has nothing to rename.
        if (color != null)
          IconButton(
            onPressed: () => _editGroupName(context, ref, color!, customName ?? '', defaultLabel),
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Rename group',
            visualDensity: VisualDensity.compact,
            color: Colors.black45,
          ),
      ],
    );
  }
}

/// Asks for a new title for [color]'s group and saves it to Firestore
/// (`food_group_names`). Saving a blank name restores the default title.
Future<void> _editGroupName(
  BuildContext context,
  WidgetRef ref,
  Color color,
  String currentName,
  String defaultLabel,
) async {
  // Tracked via onChanged (not a controller disposed after the dialog
  // closes) — same reason as `showAddFoodDialog`.
  var entered = currentName;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Rename Group'),
        content: TextFormField(
          autofocus: true,
          initialValue: currentName,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: defaultLabel,
            helperText: 'Leave blank to use the default name.',
          ),
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
  if (result == null || !context.mounted) return;

  if (!await hasNetworkConnection()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please check your internet connection.')),
      );
    }
    return;
  }
  try {
    await ref.read(foodGroupNameRepositoryProvider).setName(color.toARGB32(), result);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(networkAwareErrorMessage(error))),
      );
    }
  }
}

/// Shows the "Add Food" dialog and, on confirm, adds it to the shared
/// [foodCatalogProvider] catalog — a top-level function (not a method on
/// [FoodSelectionScreen]) so a host screen embedding the food list header-less
/// (e.g. `LogHomeScreen`) can trigger the same dialog from its own "Add Item"
/// button instead of duplicating this logic.
Future<void> showAddFoodDialog(BuildContext context, WidgetRef ref) async {
  final formKey = GlobalKey<FormState>();
  // Tracked via onChanged rather than a TextEditingController — the
  // dialog's own exit transition can still be rebuilding briefly after
  // showDialog() resolves, so a controller disposed immediately after
  // would be used-after-dispose.
  var enteredName = '';
  var enteredTargetTemperature = '';
  Color? selectedColor;

  final result =
      await showDialog<
        ({String name, Color? color, double? targetTemperature})
      >(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setState) {
              return AlertDialog(
                title: const Text('Add Food'),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Food name',
                        ),
                        onChanged: (value) => enteredName = value,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Enter a food name'
                            : null,
                        onFieldSubmitted: (value) {
                          if (formKey.currentState!.validate()) {
                            Navigator.of(dialogContext).pop((
                              name: value.trim(),
                              color: selectedColor,
                              targetTemperature: double.tryParse(
                                enteredTargetTemperature,
                              ),
                            ));
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Target Temperature (optional)',
                          suffixText: '°F',
                        ),
                        onChanged: (value) => enteredTargetTemperature = value,
                        validator: (value) =>
                            (value != null &&
                                value.trim().isNotEmpty &&
                                double.tryParse(value) == null)
                            ? 'Enter a valid number'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Category color (optional)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final color in _foodCategoryColors)
                            GestureDetector(
                              onTap: () => setState(
                                () => selectedColor = selectedColor == color
                                    ? null
                                    : color,
                              ),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectedColor == color
                                        ? Colors.black87
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: selectedColor == color
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.of(dialogContext).pop((
                          name: enteredName.trim(),
                          color: selectedColor,
                          targetTemperature: double.tryParse(
                            enteredTargetTemperature,
                          ),
                        ));
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
      );

  if (result == null || result.name.isEmpty || !context.mounted) return;

  final added = await ref
      .read(foodCatalogProvider.notifier)
      .addFood(
        result.name,
        color: result.color,
        targetTemperature: result.targetTemperature,
      );
  if (!added && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${result.name}" is already in the list.')),
    );
  }
}
