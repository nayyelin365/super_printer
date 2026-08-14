import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../label_printing/presentation/label_print_controller.dart';
import '../../printer_workspace/presentation/printer_workspace_screen.dart';
import 'food_selection_controller.dart';
import 'widgets/food_card.dart';

/// First step of the printing flow: pick which food/menu item the label is
/// for. Selecting one starts a fresh label (see
/// [LabelPrintController.startNewLabel]) pre-filled with that name and
/// opens the printer workspace — the food catalog itself is never modified.
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
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
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
                  const Text(
                    'Select Food',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: foods.length,
                      itemBuilder: (context, index) {
                        final food = foods[index];
                        return FoodCard(
                          name: food,
                          onSelect: () => _selectFood(context, ref, food),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectFood(BuildContext context, WidgetRef ref, String food) {
    ref.read(labelPrintControllerProvider.notifier).startNewLabel(food);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrinterWorkspaceScreen()),
    );
  }
}
