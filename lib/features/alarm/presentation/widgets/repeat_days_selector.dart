import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

const repeatDayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
const _weekdays = {1, 2, 3, 4, 5};
const _weekends = {6, 7};
const _allDays = {1, 2, 3, 4, 5, 6, 7};

/// Mon..Sun toggle chips, plus quick presets (Never / Every day / Weekdays
/// / Weekends) that just set [selected] to the matching set outright -
/// "Custom" isn't its own button, it's simply whatever the chips currently
/// show that doesn't match one of the other presets.
class RepeatDaysSelector extends StatelessWidget {
  const RepeatDaysSelector({super.key, required this.selected, required this.onChanged});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  bool _presetSelected(Set<int> preset) =>
      selected.length == preset.length && selected.containsAll(preset);

  void _toggleDay(int day) {
    final next = {...selected};
    if (!next.add(day)) next.remove(day);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var day = 1; day <= 7; day++) ...[
              if (day > 1) const SizedBox(width: 6),
              Expanded(
                child: _DayToggle(
                  label: repeatDayLabels[day]!,
                  on: selected.contains(day),
                  onTap: () => _toggleDay(day),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PresetChip(
              label: 'Never',
              selected: selected.isEmpty,
              onTap: () => onChanged(const {}),
            ),
            _PresetChip(
              label: 'Every day',
              selected: _presetSelected(_allDays),
              onTap: () => onChanged(_allDays),
            ),
            _PresetChip(
              label: 'Weekdays',
              selected: _presetSelected(_weekdays),
              onTap: () => onChanged(_weekdays),
            ),
            _PresetChip(
              label: 'Weekends',
              selected: _presetSelected(_weekends),
              onTap: () => onChanged(_weekends),
            ),
          ],
        ),
      ],
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppTheme.amber : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? AppTheme.amber : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: on ? AppTheme.navyDark : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.amber,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppTheme.navyDark : Colors.black87,
      ),
    );
  }
}
