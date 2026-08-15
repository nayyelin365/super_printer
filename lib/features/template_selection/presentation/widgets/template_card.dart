import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../label_printing/domain/label_data.dart';
import '../../../label_printing/domain/label_template.dart';
import '../../../label_printing/presentation/widgets/label_preview.dart';

/// A selectable card on the Template Selection screen. The thumbnail is a
/// live render from the same [LabelPreview] used on the print page (with
/// representative sample data) — not a static image — so it never drifts
/// out of sync with the actual template design.
class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.sampleData,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
  });

  final LabelTemplate template;
  final LabelData sampleData;
  final bool selected;
  final VoidCallback onTap;

  /// Only used for custom (non built-in) templates.
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.amber : AppTheme.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: LabelPreview(data: sampleData),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  if (!template.isBuiltIn)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: PopupMenuButton<_TemplateAction>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, size: 18),
                        tooltip: 'Template options',
                        onSelected: (action) => switch (action) {
                          _TemplateAction.edit => onEdit?.call(),
                          _TemplateAction.duplicate => onDuplicate?.call(),
                          _TemplateAction.delete => onDelete?.call(),
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: _TemplateAction.edit, child: Text('Edit')),
                          PopupMenuItem(value: _TemplateAction.duplicate, child: Text('Duplicate')),
                          PopupMenuItem(value: _TemplateAction.delete, child: Text('Delete')),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                template.description,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      template.isBuiltIn ? 'Built-in' : 'Custom',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                        SizedBox(width: 4),
                        Text(
                          'Selected',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TemplateAction { edit, duplicate, delete }
