import 'dart:typed_data';

import 'models/printer_calibration.dart';
import 'models/printer_device.dart';

enum PrinterConnectionStatus { disconnected, connecting, connected }

/// Platform/transport-agnostic contract for a label printer.
///
/// UI code must only ever talk to this interface — never to
/// Bluetooth/USB/Zebra APIs directly. Concrete implementations
/// ([BluetoothLabelPrinter], [UsbLabelPrinter]) isolate that logic.
abstract class LabelPrinter {
  /// Scan for available printers. Implementations must stop scanning after
  /// a reasonable timeout rather than scanning indefinitely.
  Future<List<PrinterDevice>> discoverPrinters();

  Future<void> connect(PrinterDevice printer);

  Future<void> disconnect();

  Future<bool> isConnected();

  /// Renders [imageBytes] (a raw white/black bitmap, one byte per pixel,
  /// 0 = white / 255 = black, row-major) as a Zebra-compatible graphic and
  /// prints it at the printer's configured [PrinterCalibration].
  ///
  /// [copies] labels are produced from this single transmitted image (via
  /// the printer's own `^PQ` copy count) rather than re-sending the bitmap
  /// once per copy.
  Future<void> printImage(
    Uint8List imageBytes, {
    required int width,
    required int height,
    PrinterCalibration calibration = const PrinterCalibration(),
    int copies = 1,
  });

  /// Stops any in-flight scan/connect operation and releases resources.
  Future<void> dispose();
}
