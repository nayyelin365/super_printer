import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../label_printing/presentation/label_print_controller.dart';
import '../../printer_workspace/presentation/printer_workspace_screen.dart';
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
  const FoodSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(filteredFoodsProvider);

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
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Select Food',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showAddFoodDialog(context, ref),
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
              child: foods.isEmpty
                  ? const Center(
                      child: Text(
                        'No food found',
                        style: TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: foods.length,
                      itemBuilder: (context, index) {
                        final food = foods[index];
                        return FoodCard(
                          name: food.name,
                          color: food.color,
                          onSelect: () => _selectFood(context, ref, food),
                          onRemove: () => _confirmRemoveFood(context, ref, food.name),
                        );
                      },
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrinterWorkspaceScreen()),
    );
  }

  Future<void> _showAddFoodDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    // Tracked via onChanged rather than a TextEditingController — the
    // dialog's own exit transition can still be rebuilding briefly after
    // showDialog() resolves, so a controller disposed immediately after
    // would be used-after-dispose.
    var enteredName = '';
    Color? selectedColor;

    final result = await showDialog<({String name, Color? color})>(
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
                      decoration: const InputDecoration(hintText: 'Food name'),
                      onChanged: (value) => enteredName = value,
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Enter a food name'
                          : null,
                      onFieldSubmitted: (value) {
                        if (formKey.currentState!.validate()) {
                          Navigator.of(dialogContext).pop((name: value.trim(), color: selectedColor));
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Category color (optional)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final color in _foodCategoryColors)
                          GestureDetector(
                            onTap: () => setState(
                              () => selectedColor = selectedColor == color ? null : color,
                            ),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == color ? Colors.black87 : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: selectedColor == color
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
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
                      Navigator.of(dialogContext)
                          .pop((name: enteredName.trim(), color: selectedColor));
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

    final added =
        await ref.read(foodCatalogProvider.notifier).addFood(result.name, color: result.color);
    if (!added && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${result.name}" is already in the list.')),
      );
    }
  }

  Future<void> _confirmRemoveFood(BuildContext context, WidgetRef ref, String food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Food'),
          content: Text('Remove "$food" from the food list? This can\'t be undone.'),
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
