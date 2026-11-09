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

  /// Sets the canvas's physical size in inches and rescales every existing
  /// component's position/size proportionally, so resizing the canvas after
  /// components have already been placed keeps the layout intact instead of
  /// clipping or orphaning anything off the new canvas.
  void setCanvasSize(double widthInches, double heightInches) {
    if (widthInches <= 0 || heightInches <= 0) return;
    final current = state.template;
    final scaleX = widthInches / current.widthInches;
    final scaleY = heightInches / current.heightInches;
    if (scaleX == 1 && scaleY == 1) return;

    final rescaled = [
      for (final c in current.components)
        c.copyWith(
          x: c.x * scaleX,
          y: c.y * scaleY,
          width: c.width * scaleX,
          height: c.height * scaleY,
          fontSize: c.fontSize * ((scaleX + scaleY) / 2),
          thickness: c.thickness * scaleY,
        ),
    ];

    state = state.copyWith(
      template: current.copyWith(
        widthInches: widthInches,
        heightInches: heightInches,
        components: rescaled,
      ),
    );
  }

  /// The grid every default position/size below was authored against — a
  /// 3 x 2 in canvas at 300 DPI. [addComponent] scales them to whatever the
  /// current draft's actual canvas size is, so a new component added on a
  /// smaller/larger custom canvas lands inside it instead of assuming the
  /// old fixed 900 x 600 grid.
  static const double _referenceWidth = 900;
  static const double _referenceHeight = 600;

  void addComponent(LabelComponentType type, {bool vertical = false, bool filled = false}) {
    final id = const Uuid().v4();
    final template = state.template;
    final scaleX = (template.widthInches * 300) / _referenceWidth;
    final scaleY = (template.heightInches * 300) / _referenceHeight;
    double sx(double v) => v * scaleX;
    double sy(double v) => v * scaleY;

    if (type == LabelComponentType.divider && vertical) {
      final component = LabelComponent(
        id: id,
        type: type,
        x: sx(450),
        y: sy(40),
        height: sy(520),
        vertical: true,
      );
      state = state.copyWith(
        template: template.copyWith(components: [...template.components, component]),
        selectedComponentId: () => id,
      );
      return;
    }

    final component = switch (type) {
      LabelComponentType.text => LabelComponent(
          id: id,
          type: type,
          value: 'Custom Text',
          x: sx(40),
          y: sy(40),
          width: sx(820),
          height: sy(50),
          fontSize: sy(28),
          bold: true,
          alignment: TextAlign.center,
        ),
      LabelComponentType.barcode => LabelComponent(
          id: id,
          type: type,
          fieldKey: LabelFieldKey.barcode,
          value: '0123456789',
          x: sx(150),
          y: sy(350),
          width: sx(600),
          height: sy(150),
        ),
      LabelComponentType.dateTime => LabelComponent(
          id: id,
          type: type,
          fieldKey: LabelFieldKey.packedDate,
          x: sx(40),
          y: sy(200),
          width: sx(400),
          height: sy(40),
          fontSize: sy(20),
        ),
      LabelComponentType.divider => LabelComponent(
          id: id,
          type: type,
          x: sx(40),
          y: sy(260),
          width: sx(820),
          height: sy(4),
        ),
      LabelComponentType.image => LabelComponent(
          id: id,
          type: type,
          x: sx(40),
          y: sy(40),
          width: sx(200),
          height: sy(200),
        ),
      LabelComponentType.box => LabelComponent(
          id: id,
          type: type,
          x: sx(100),
          y: sy(100),
          width: sx(300),
          height: sy(200),
          filled: filled,
        ),
    };

    state = state.copyWith(
      template: template.copyWith(
        components: [...template.components, component],
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
    updateComponentById(selectedId, update);
  }

  /// Same mutation as [updateSelectedComponent] but by an explicit [id]
  /// rather than whatever's currently selected — used by the interactive
  /// canvas overlay, where a drag can move/resize a component in the same
  /// gesture that selects it, without depending on selection state having
  /// already propagated through a rebuild.
  void updateComponentById(String id, LabelComponent Function(LabelComponent current) update) {
    state = state.copyWith(
      template: state.template.copyWith(
        components: [
          for (final c in state.template.components)
            if (c.id == id) update(c) else c,
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
