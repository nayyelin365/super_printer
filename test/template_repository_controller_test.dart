import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:super_printer/features/label_printing/domain/label_component.dart';
import 'package:super_printer/features/label_printing/domain/label_template.dart';
import 'package:super_printer/features/template_builder/presentation/template_repository_controller.dart';

LabelTemplate _sampleTemplate({String id = 'tmpl_1', String name = 'My Kitchen Label'}) {
  return LabelTemplate(
    id: id,
    name: name,
    type: LabelTemplateType.custom,
    isBuiltIn: false,
    requiresFoodSelection: true,
    components: [
      const LabelComponent(
        id: 'c1',
        type: LabelComponentType.text,
        fieldKey: LabelFieldKey.foodName,
      ),
    ],
  );
}

void main() {
  group('CustomTemplateNotifier', () {
    test('addTemplate persists and later containers restore it (survives restart)', () async {
      SharedPreferences.setMockInitialValues({});

      final firstContainer = ProviderContainer();
      await firstContainer.read(customTemplatesProvider.notifier).addTemplate(_sampleTemplate());
      firstContainer.dispose();

      final secondContainer = ProviderContainer();
      addTearDown(secondContainer.dispose);
      secondContainer.read(customTemplatesProvider); // trigger lazy construction
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final restored = secondContainer.read(customTemplatesProvider);
      expect(restored, hasLength(1));
      expect(restored.single.name, 'My Kitchen Label');
      expect(restored.single.components.single.fieldKey, LabelFieldKey.foodName);
    });

    test('built-ins are never included in the persisted custom list', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(customTemplatesProvider.notifier).addTemplate(_sampleTemplate());

      final allTemplates = container.read(allTemplatesProvider);
      expect(allTemplates.map((t) => t.id), contains(LabelTemplateCatalog.pokeBowlBurrito.id));
      expect(allTemplates.map((t) => t.id), contains(LabelTemplateCatalog.foodRotation.id));
      expect(allTemplates.where((t) => t.isBuiltIn), hasLength(2));
      expect(allTemplates.where((t) => !t.isBuiltIn), hasLength(1));
    });

    test('updateTemplate replaces in place rather than appending', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(customTemplatesProvider.notifier);
      await notifier.addTemplate(_sampleTemplate());
      final updated = _sampleTemplate(name: 'Renamed Label');
      await notifier.updateTemplate(updated);

      final all = container.read(customTemplatesProvider);
      expect(all, hasLength(1));
      expect(all.single.name, 'Renamed Label');
    });

    test('duplicateTemplate creates a new id, never reusing the original', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(customTemplatesProvider.notifier);
      final original = _sampleTemplate();
      await notifier.addTemplate(original);
      final copy = await notifier.duplicateTemplate(original);

      expect(copy.id, isNot(original.id));
      expect(copy.name, 'My Kitchen Label Copy');
      expect(copy.isBuiltIn, isFalse);
      expect(container.read(customTemplatesProvider), hasLength(2));
    });

    test('deleteTemplate removes it and persists the removal', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(customTemplatesProvider.notifier);
      await notifier.addTemplate(_sampleTemplate());
      await notifier.deleteTemplate('tmpl_1');

      expect(container.read(customTemplatesProvider), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_templates'), contains('"templates":[]'));
    });
  });
}
