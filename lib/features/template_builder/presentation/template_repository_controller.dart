import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../label_printing/domain/label_template.dart';
import '../data/template_storage.dart';

final templateStorageProvider = Provider<TemplateStorage>((ref) => TemplateStorage());

/// Owns the set of user-created templates: loads them on startup and keeps
/// [TemplateStorage] in sync with every add/update/delete/duplicate. Widgets
/// never touch [TemplateStorage] directly.
class CustomTemplateNotifier extends StateNotifier<List<LabelTemplate>> {
  CustomTemplateNotifier(this._storage) : super([]) {
    _restore();
  }

  final TemplateStorage _storage;

  Future<void> _restore() async {
    final saved = await _storage.loadAll();
    state = saved;
  }

  Future<void> addTemplate(LabelTemplate template) async {
    state = [...state, template];
    await _storage.saveAll(state);
  }

  /// Replaces the template with a matching id (never appends a duplicate).
  Future<void> updateTemplate(LabelTemplate template) async {
    state = [for (final t in state) if (t.id == template.id) template else t];
    await _storage.saveAll(state);
  }

  Future<void> deleteTemplate(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _storage.saveAll(state);
  }

  Future<LabelTemplate> duplicateTemplate(LabelTemplate template) async {
    final copy = LabelTemplate(
      id: const Uuid().v4(),
      name: '${template.name} Copy',
      description: template.description,
      type: template.type,
      widthInches: template.widthInches,
      heightInches: template.heightInches,
      dpi: template.dpi,
      components: template.components,
      isBuiltIn: false,
      requiresFoodSelection: template.requiresFoodSelection,
      supportsBarcode: template.supportsBarcode,
    );
    state = [...state, copy];
    await _storage.saveAll(state);
    return copy;
  }
}

final customTemplatesProvider =
    StateNotifierProvider<CustomTemplateNotifier, List<LabelTemplate>>(
  (ref) => CustomTemplateNotifier(ref.watch(templateStorageProvider)),
);

/// Built-ins followed by custom templates — the full list Template
/// Selection displays.
final allTemplatesProvider = Provider<List<LabelTemplate>>((ref) {
  final custom = ref.watch(customTemplatesProvider);
  return [...LabelTemplateCatalog.builtIns, ...custom];
});
