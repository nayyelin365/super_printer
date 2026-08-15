import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../label_printing/domain/label_component.dart';
import '../../label_printing/domain/label_template.dart';
import 'template_repository_controller.dart';

/// Set right before navigating to the Template Builder screen: `null` to
/// create a new template, or an existing custom template to edit. Read once
/// by [TemplateBuilderController] to seed its draft — mirrors how
/// `PrinterSetupController` seeds itself from the active printer session.
final editingTemplateProvider = StateProvider<LabelTemplate?>((ref) => null);

class TemplateBuilderState {
  TemplateBuilderState({
    required this.template,
    this.selectedComponentId,
    this.isSaving = false,
    this.saved = false,
    this.errorMessage,
    this.isEditing = false,
  });

  final LabelTemplate template;
  final String? selectedComponentId;
  final bool isSaving;
  final bool saved;
  final String? errorMessage;
  final bool isEditing;

  LabelComponent? get selectedComponent {
    final id = selectedComponentId;
    if (id == null) return null;
    for (final c in template.components) {
      if (c.id == id) return c;
    }
    return null;
  }

  TemplateBuilderState copyWith({
    LabelTemplate? template,
    String? Function()? selectedComponentId,
    bool? isSaving,
    bool? saved,
    String? Function()? errorMessage,
  }) {
    return TemplateBuilderState(
      template: template ?? this.template,
      selectedComponentId:
          selectedComponentId != null ? selectedComponentId() : this.selectedComponentId,
      isSaving: isSaving ?? this.isSaving,
      saved: saved ?? this.saved,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isEditing: isEditing,
    );
  }
}

class TemplateBuilderController extends StateNotifier<TemplateBuilderState> {
  TemplateBuilderController(this._ref, LabelTemplate? existing)
      : isEditing = existing != null,
        super(TemplateBuilderState(
          template: existing ?? _blankTemplate(),
          isEditing: existing != null,
        ));

  final Ref _ref;
  final bool isEditing;

  static LabelTemplate _blankTemplate() => LabelTemplate(
        id: const Uuid().v4(),
        name: '',
        type: LabelTemplateType.custom,
        isBuiltIn: false,
        requiresFoodSelection: false,
      );

  void setName(String name) {
    state = state.copyWith(
      template: state.template.copyWith(name: name),
      errorMessage: () => null,
    );
  }

  void setRequiresFoodSelection(bool value) {
    state = state.copyWith(
      template: state.template.copyWith(requiresFoodSelection: value),
    );
  }

  void addComponent(LabelComponentType type) {
    final id = const Uuid().v4();
    final component = switch (type) {
      LabelComponentType.text => LabelComponent(
          id: id,
          type: type,
          value: 'Custom Text',
          x: 40,
          y: 40,
          width: 820,
          height: 50,
          fontSize: 28,
          bold: true,
          alignment: TextAlign.center,
        ),
      LabelComponentType.barcode => LabelComponent(
          id: id,
          type: type,
          fieldKey: LabelFieldKey.barcode,
          value: '0123456789',
          x: 150,
          y: 350,
          width: 600,
          height: 150,
        ),
      LabelComponentType.dateTime => LabelComponent(
          id: id,
          type: type,
          fieldKey: LabelFieldKey.packedDate,
          x: 40,
          y: 200,
          width: 400,
          height: 40,
          fontSize: 20,
        ),
      LabelComponentType.divider => LabelComponent(
          id: id,
          type: type,
          x: 40,
          y: 260,
          width: 820,
          height: 4,
        ),
      LabelComponentType.image => LabelComponent(
          id: id,
          type: type,
          x: 40,
          y: 40,
          width: 200,
          height: 200,
        ),
    };

    state = state.copyWith(
      template: state.template.copyWith(
        components: [...state.template.components, component],
      ),
      selectedComponentId: () => id,
    );
  }

  void selectComponent(String? id) {
    state = state.copyWith(selectedComponentId: () => id);
  }

  void removeComponent(String id) {
    state = state.copyWith(
      template: state.template.copyWith(
        components: state.template.components.where((c) => c.id != id).toList(),
      ),
      selectedComponentId: () => state.selectedComponentId == id ? null : state.selectedComponentId,
    );
  }

  void updateSelectedComponent(LabelComponent Function(LabelComponent current) update) {
    final selectedId = state.selectedComponentId;
    if (selectedId == null) return;
    state = state.copyWith(
      template: state.template.copyWith(
        components: [
          for (final c in state.template.components)
            if (c.id == selectedId) update(c) else c,
        ],
      ),
    );
  }

  Future<bool> save() async {
    final name = state.template.name.trim();
    if (name.isEmpty) {
      state = state.copyWith(errorMessage: () => 'Enter a template name.');
      return false;
    }
    if (state.template.components.isEmpty) {
      state = state.copyWith(errorMessage: () => 'Add at least one component.');
      return false;
    }

    state = state.copyWith(isSaving: true, errorMessage: () => null);
    final toSave = state.template.copyWith(name: name);
    final repo = _ref.read(customTemplatesProvider.notifier);
    if (isEditing) {
      await repo.updateTemplate(toSave);
    } else {
      await repo.addTemplate(toSave);
    }
    state = state.copyWith(isSaving: false, saved: true, template: toSave);
    return true;
  }
}

final templateBuilderControllerProvider =
    StateNotifierProvider.autoDispose<TemplateBuilderController, TemplateBuilderState>(
  (ref) => TemplateBuilderController(ref, ref.read(editingTemplateProvider)),
);
