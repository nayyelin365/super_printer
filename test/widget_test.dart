import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:super_printer/app.dart';

void main() {
  testWidgets('Home screen leads to the label print screen',
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
    expect(find.text('MENU LABEL SYSTEM'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Print a Label'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Print a Label'));
    await tester.pumpAndSettle();

    expect(find.text('Menu Label Print'), findsOneWidget);
    expect(find.text('LABEL PREVIEW'), findsOneWidget);
    expect(find.text('Print Details'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Print'), findsOneWidget);

    // The edit button on the print screen opens printer settings.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Printer Settings'), findsOneWidget);

    // The close button dismisses it back to the print screen.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Printer Settings'), findsNothing);
    expect(find.text('Print Details'), findsOneWidget);
  });
}
