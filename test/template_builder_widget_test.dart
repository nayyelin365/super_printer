import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:super_printer/app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: SuperPrinterApp()));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Create a custom template, select and print it, then duplicate and delete it',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Print a Label'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Label Template'), findsOneWidget);

    // Only the two built-ins exist initially.
    expect(find.text('Custom Poke Bowl / Burrito'), findsOneWidget);
    expect(find.text('Food Rotation Label'), findsOneWidget);
    expect(find.text('My Kitchen Label'), findsNothing);

    // Create a new template.
    await tester.tap(find.byTooltip('Create Template'));
    await tester.pumpAndSettle();
    expect(find.text('Create Template'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. My Kitchen Label'),
      'My Kitchen Label',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '+ Text'));
    await tester.pumpAndSettle();

    // Adding a component selects it; the property editor appears.
    expect(find.text('Select a component to edit its properties.'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    // Back on Template Selection, the new custom template is listed.
    expect(find.text('Choose Label Template'), findsOneWidget);
    expect(find.text('My Kitchen Label'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    // Select it and continue — it doesn't require food selection by
    // default, so it should go straight to the print page.
    await tester.tap(find.text('My Kitchen Label'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Select Food'), findsNothing);
    expect(find.text('Menu Label Print'), findsOneWidget);
    expect(find.text('LABEL PREVIEW'), findsOneWidget);
    expect(find.text('Print Details'), findsOneWidget);
    // Template name shown in the print details panel.
    expect(find.text('My Kitchen Label'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Print'), findsOneWidget);

    // Back to Template Selection to duplicate and delete.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Label Template'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    expect(find.text('My Kitchen Label Copy'), findsOneWidget);

    // Delete the original; built-ins never show a "more" menu, so this
    // targets the first of the two remaining custom cards.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Template?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // One custom template deleted; the other (the copy) and both built-ins
    // remain.
    expect(find.text('Custom Poke Bowl / Burrito'), findsOneWidget);
    expect(find.text('Food Rotation Label'), findsOneWidget);
    expect(find.text('My Kitchen Label Copy'), findsOneWidget);
  });
}
