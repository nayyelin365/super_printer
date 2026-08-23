import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../food_selection/presentation/food_selection_screen.dart';
import 'log_type_list_screen.dart';

/// Routed at `/logs` — hosts the two Log Sheet tabs: "Item Lists" (the
/// existing Food feature, reused as-is via [FoodSelectionScreen] rather
/// than a separate food-management UI) and "Log Sheet" (the six log-type
/// cards, [LogTypeListScreen]).
class LogHomeScreen extends ConsumerStatefulWidget {
  const LogHomeScreen({super.key});

  @override
  ConsumerState<LogHomeScreen> createState() => _LogHomeScreenState();
}

class _LogHomeScreenState extends ConsumerState<LogHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Food Preparation Log Sheet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  // Only the Item Lists tab manages food entries — the Log
                  // Sheet tab's six log types are a fixed set, not addable.
                  if (_tabIndex == 0)
                    OutlinedButton.icon(
                      onPressed: () => showAddFoodDialog(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _TabChip(
                    icon: Icons.set_meal_outlined,
                    label: 'Item Lists',
                    selected: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                  const SizedBox(width: 10),
                  _TabChip(
                    icon: Icons.description_outlined,
                    label: 'Log Sheet',
                    selected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                ],
              ),
            ),
            Expanded(
              // IndexedStack (not a rebuild-on-switch) so the Food catalog
              // stream and its search state stay alive when flipping tabs.
              child: IndexedStack(
                index: _tabIndex,
                sizing: StackFit.expand,
                children: const [
                  FoodSelectionScreen(showHeader: false),
                  LogTypeListScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.navyDark : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Colors.transparent : AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : Colors.black54),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
