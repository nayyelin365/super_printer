import 'bluetooth_label_printer.dart';
import 'label_printer.dart';
import 'models/connection_type.dart';
import 'usb_label_printer.dart';

/// Creates the correct [LabelPrinter] implementation for a connection type.
///
/// Centralizing this keeps every other layer (UI, controllers) ignorant of
/// which concrete transport classes exist.
class PrinterRegistry {
  PrinterRegistry._();

  static LabelPrinter create(PrinterConnectionType type) {
    return switch (type) {
      PrinterConnectionType.bluetooth => BluetoothLabelPrinter(),
      PrinterConnectionType.usb => UsbLabelPrinter(),
    };
  }
}
