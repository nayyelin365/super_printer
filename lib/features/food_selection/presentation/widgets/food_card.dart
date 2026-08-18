import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

class FoodCard extends StatelessWidget {
  const FoodCard({
    super.key,
    required this.name,
    required this.onSelect,
    required this.onRemove,
    this.color,
  });

  final String name;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  /// Category color picked when this food was added — shown as a left
  /// accent stripe and a light background tint so foods in the same
  /// category are easy to tell apart at a glance. Null falls back to a
  /// plain white card.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppTheme.border;

    // The accent stripe is painted as its own Container inside a Row
    // (not as part of a BoxDecoration border) — a border with a wider
    // left side than the others isn't uniform, and Flutter refuses to
    // paint a non-uniform border together with a borderRadius, which
    // silently dropped the card's whole content in painting.
    return Material(
      color: color?.withValues(alpha: 0.10) ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onSelect,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: onSelect,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.navyDark,
                              side: const BorderSide(color: AppTheme.navyDark),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Select',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 14),
              tooltip: 'Remove $name',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: EdgeInsets.zero,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}
