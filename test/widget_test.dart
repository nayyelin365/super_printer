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
      'Template 1 (Poke Bowl) skips Food Selection and goes straight to the print page',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Print a Label'));
    await tester.pumpAndSettle();

    // Template Selection screen, Poke Bowl selected by default.
    expect(find.text('Choose Label Template'), findsOneWidget);
    expect(find.text('Custom Poke Bowl / Burrito'), findsOneWidget);
    expect(find.text('Food Rotation Label'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Continue'));
    await tester.pumpAndSettle();

    // Straight to the print page — no Food Selection in between.
    expect(find.text('Select Food'), findsNothing);
    expect(find.text('Menu Label Print'), findsOneWidget);
    expect(find.text('LABEL PREVIEW'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Product Name'), findsOneWidget);
    expect(find.text('Print Details'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Print'), findsOneWidget);

    // Poke Bowl-only sections are present.
    expect(find.textContaining('Barcode:'), findsOneWidget);
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Barcode:'), findsNothing);

    // Printer settings edit/close flow still works from the print page.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Printer Settings'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Printer Settings'), findsNothing);

    // Back returns to Template Selection, not Food Selection.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Label Template'), findsOneWidget);
  });

  testWidgets(
      'Template 2 (Food Rotation) routes through Food Selection and shows only its own fields',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Print a Label'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Food Rotation Label'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Continue'));
    await tester.pumpAndSettle();

    // Food Selection screen.
    expect(find.text('Select Food'), findsOneWidget);
    expect(find.text('Classic Pancakes'), findsOneWidget);

    // Real-time, case-insensitive search; empty state on no match.
    await tester.enterText(find.byType(TextField), 'egg');
    await tester.pumpAndSettle();
    expect(find.text('Classic Pancakes'), findsNothing);
    expect(find.text('Egg & Cheese Sandwich'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pumpAndSettle();
    expect(find.text('No food found'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Belgian');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Select'));
    await tester.pumpAndSettle();

    // Print page pre-filled with the picked food name, Food Rotation fields.
    expect(find.text('Menu Label Print'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Belgian Waffles'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Food Name'), findsOneWidget);
    expect(find.text('Prep Date & Time'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Employee'), findsOneWidget);

    // Poke Bowl-only fields/sections must not leak into this template.
    expect(find.widgetWithText(TextFormField, 'Product Name'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Net Weight (lb)'), findsNothing);
    expect(find.textContaining('Barcode:'), findsNothing);
    expect(find.text('Show Barcode'), findsNothing);

    // PH is off by default (no field shown, just the switch), and appears
    // once toggled on.
    expect(find.text('Show PH'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'PH'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'PH'), findsOneWidget);

    expect(find.text('Print Details'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Print'), findsOneWidget);

    // Back returns to Food Selection (template preserved), not Template
    // Selection directly.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Select Food'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Label Template'), findsOneWidget);
  });

  testWidgets(
      'Food Selection: + opens an add dialog; a card\'s remove icon opens a confirm dialog',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Print a Label'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food Rotation Label'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Select Food'), findsOneWidget);

    // Filter to a single card so both the add flow and the remove flow
    // below act on a predictable, always-built widget (the full catalog
    // grid is long enough that off-screen items aren't built by
    // GridView.builder, which is unrelated to the behavior under test).
    // A partial query (not the full name) avoids the search box's own
    // typed text colliding with `find.text('Classic Pancakes')` below —
    // Flutter's `find.text` also matches the EditableText showing it.
    await tester.enterText(find.byType(TextField), 'Classic Panc');
    await tester.pumpAndSettle();
    expect(find.text('Classic Pancakes'), findsOneWidget);

    // The + button opens an add-food dialog; Cancel dismisses it without
    // adding anything.
    await tester.tap(find.byTooltip('Add food'));
    await tester.pumpAndSettle();
    expect(find.text('Add Food'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Add Food'), findsNothing);

    // The card's remove icon opens a confirm dialog; Cancel leaves the
    // card in place.
    await tester.tap(find.byTooltip('Remove Classic Pancakes'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Food'), findsOneWidget);
    expect(find.textContaining('Classic Pancakes'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Food'), findsNothing);
    expect(find.text('Classic Pancakes'), findsOneWidget);

    // Confirming removal takes the card out of the (filtered) list.
    await tester.tap(find.byTooltip('Remove Classic Pancakes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Classic Pancakes'), findsNothing);
    expect(find.text('No food found'), findsOneWidget);
  });
}
