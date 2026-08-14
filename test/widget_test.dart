import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:super_printer/app.dart';

void main() {
  testWidgets('Home -> Food Selection -> Menu Label Print flow',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: SuperPrinterApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('FLAVORHUB'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Print a Label'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Print a Label'));
    await tester.pumpAndSettle();

    // Food Selection screen.
    expect(find.text('Select Food'), findsOneWidget);
    expect(find.text('Classic Pancakes'), findsOneWidget);
    expect(find.text('French Toast'), findsOneWidget);

    // Real-time search filters the grid.
    await tester.enterText(find.byType(TextField), 'egg');
    await tester.pumpAndSettle();
    expect(find.text('Classic Pancakes'), findsNothing);
    expect(find.text('Scrambled Eggs & Toast'), findsOneWidget);

    // No matches shows the empty state, not a blank grid.
    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pumpAndSettle();
    expect(find.text('No food found'), findsOneWidget);

    // Selecting a food opens Menu Label Print pre-filled with its name.
    await tester.enterText(find.byType(TextField), 'Belgian');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Select'));
    await tester.pumpAndSettle();

    expect(find.text('Menu Label Print'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Belgian Waffles'), findsOneWidget);
    expect(find.text('LABEL PREVIEW'), findsOneWidget);
    expect(find.text('Print Details'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Print'), findsOneWidget);

    // Barcode toggle hides the barcode caption entirely (no blank gap left
    // behind in the details panel either).
    expect(find.textContaining('Barcode:'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Barcode:'), findsNothing);

    // Back returns to Food Selection.
    await tester.tap(find.byTooltip('Back to Food Selection'));
    await tester.pumpAndSettle();
    expect(find.text('Select Food'), findsOneWidget);

    // Printer settings edit/close flow still works from the label screen.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Select').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Printer Settings'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Printer Settings'), findsNothing);
    expect(find.text('Print Details'), findsOneWidget);
  });
}
