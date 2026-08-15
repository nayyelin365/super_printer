import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/label_printing/presentation/label_print_controller.dart';

void main() {
  group('LabelPrintController.useByDuration', () {
    test('1-24 is interpreted as hours', () {
      expect(LabelPrintController.useByDuration(12), const Duration(hours: 12));
      expect(LabelPrintController.useByDuration(1), const Duration(hours: 1));
      expect(LabelPrintController.useByDuration(24), const Duration(hours: 24));
    });

    test('25+ is interpreted as days', () {
      expect(LabelPrintController.useByDuration(48), const Duration(days: 48));
      expect(LabelPrintController.useByDuration(124), const Duration(days: 124));
      expect(LabelPrintController.useByDuration(25), const Duration(days: 25));
    });
  });
}
