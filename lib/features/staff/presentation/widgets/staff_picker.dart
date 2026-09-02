import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/network_error.dart';
import '../staff_controller.dart';

/// Single-select staff picker: a free-text "Enter Name" field plus a chip
/// grid of existing staff — matches the Sushi Rice Soaking "who is starting
/// this" step. Typing a name not already in the roster and continuing adds
/// it (so the roster grows organically instead of needing a separate
/// management screen).
class StaffNamePicker extends ConsumerStatefulWidget {
  const StaffNamePicker({super.key, required this.selectedId, required this.onChanged});

  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<StaffNamePicker> createState() => _StaffNamePickerState();
}

class _StaffNamePickerState extends ConsumerState<StaffNamePicker> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffMembersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter Your Name', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'Enter Name'),
          onSubmitted: (value) => _addAndSelect(value),
        ),
        const SizedBox(height: 12),
        staffAsync.when(
          data: (staff) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final member in staff)
                ChoiceChip(
                  label: Text(member.name),
                  selected: widget.selectedId == member.id,
                  selectedColor: AppTheme.success.withValues(alpha: 0.25),
                  onSelected: (_) => widget.onChanged(member.id),
                ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => const Text(
            'Could not load staff list.',
            style: TextStyle(color: AppTheme.danger, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _addAndSelect(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final existing = ref.read(staffMembersProvider).valueOrNull ?? const [];
    final match = existing.where((s) => s.name.toLowerCase() == trimmed.toLowerCase()).firstOrNull;
    if (match != null) {
      widget.onChanged(match.id);
      _nameController.clear();
      return;
    }

    if (!await hasNetworkConnection()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please check your internet connection.')),
        );
      }
      return;
    }

    try {
      final member = await ref.read(staffControllerProvider).add(trimmed);
      widget.onChanged(member.id);
      _nameController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
      }
    }
  }
}
