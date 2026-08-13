import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppSection { print, settings }

/// Left navigation rail shown on the printing and settings screens.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, required this.selected, required this.onSelect});

  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      color: AppTheme.navyDark,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.amber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.print, color: AppTheme.navyDark),
          ),
          const SizedBox(height: 24),
          _NavIcon(
            icon: Icons.print_outlined,
            selected: selected == AppSection.print,
            onTap: () => onSelect(AppSection.print),
            tooltip: 'Print',
          ),
          const SizedBox(height: 8),
          _NavIcon(
            icon: Icons.settings_outlined,
            selected: selected == AppSection.settings,
            onTap: () => onSelect(AppSection.settings),
            tooltip: 'Printer Settings',
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: AppTheme.amber, width: 1.5)
                : null,
          ),
          child: Icon(
            icon,
            color: selected ? AppTheme.amber : Colors.white70,
            size: 20,
          ),
        ),
      ),
    );
  }
}
