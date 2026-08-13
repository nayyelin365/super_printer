import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:super_printer/app.dart';

void main() {
  testWidgets('Label print screen renders the preview and print details',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: SuperPrinterApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Menu Label Print'), findsOneWidget);
    expect(find.text('LABEL PREVIEW'), findsOneWidget);
    expect(find.text('Print Details'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Print'), findsOneWidget);
  });
}
