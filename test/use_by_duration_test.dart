import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/label_printing/presentation/label_print_controller.dart';

void main() {
  group('LabelPrintController.useByDuration', () {
    test('any amount is interpreted as hours', () {
      expect(LabelPrintController.useByDuration(1), const Duration(hours: 1));
      expect(LabelPrintController.useByDuration(12), const Duration(hours: 12));
      expect(LabelPrintController.useByDuration(24), const Duration(hours: 24));
      expect(LabelPrintController.useByDuration(25), const Duration(hours: 25));
      expect(LabelPrintController.useByDuration(48), const Duration(hours: 48));
      expect(LabelPrintController.useByDuration(124), const Duration(hours: 124));
    });
  });
}
