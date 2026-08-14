import 'dart:convert';
import 'dart:io';

import 'package:drago_usb_printer/drago_usb_printer.dart';
import 'package:flutter/foundation.dart';

import 'chunked_writer.dart';
import 'label_printer.dart';
import 'models/connection_type.dart';
import 'models/printer_calibration.dart';
import 'models/printer_device.dart';
import 'printer_exceptions.dart';
import 'zpl_encoder.dart';

/// USB transport for Zebra printers, built on `drago_usb_printer`.
///
/// Talks to the printer directly by USB vendor/product id (as an Android
/// `UsbDevice`), not as a generic serial port with a negotiated baud rate —
/// this is what actually works reliably with Zebra USB printers, which
/// don't behave like a standard USB-serial adapter. Android only; other
/// desktop platforms would need a separate raw-USB or OS print-spooler
/// adapter behind this same [LabelPrinter] interface.
class UsbLabelPrinter implements LabelPrinter {
  final ZplEncoder _encoder = const ZplEncoder();
  final DragoUsbPrinter _usbPrinter = DragoUsbPrinter();
  bool _connected = false;

  bool get _supportedPlatform => !kIsWeb && Platform.isAndroid;

  @override
  Future<List<PrinterDevice>> discoverPrinters() async {
    if (!_supportedPlatform) {
      throw const PrinterException(
        PrinterErrorCode.usbUnavailable,
        'USB printing is not supported on this platform.',
      );
    }

    try {
      final devices = await DragoUsbPrinter.getUSBDeviceList();
      return devices.map((d) {
        final vendorId = int.tryParse('${d['vendorId'] ?? ''}') ?? 0;
        final productId = int.tryParse('${d['productId'] ?? ''}') ?? 0;
        final productName = (d['productName'] as String?) ?? '';
        final deviceName = (d['deviceName'] as String?) ?? '';
        return PrinterDevice(
          name: productName.isNotEmpty ? productName : deviceName,
          address: '$vendorId:$productId',
          connectionType: PrinterConnectionType.usb,
          usbVendorId: vendorId,
          usbProductId: productId,
          usbDeviceName: deviceName,
        );
      }).toList();
    } catch (e) {
      throw PrinterException(
        PrinterErrorCode.usbUnavailable,
        'Unable to search for USB printers.',
        cause: e,
      );
    }
  }

  @override
  Future<void> connect(PrinterDevice printer) async {
    if (!_supportedPlatform) {
      throw const PrinterException(
        PrinterErrorCode.usbUnavailable,
        'USB printing is not supported on this platform.',
      );
    }
    if (printer.connectionType != PrinterConnectionType.usb ||
        printer.usbVendorId == null ||
        printer.usbProductId == null) {
      throw const PrinterException(
        PrinterErrorCode.connectionFailed,
        'Not a USB device.',
      );
    }

    await disconnect();

    bool connected;
    try {
      connected = await _usbPrinter
          .connect(printer.usbVendorId!, printer.usbProductId!)
          .timeout(const Duration(seconds: 10), onTimeout: () => false) ??
          false;
    } catch (e) {
      throw PrinterException(
        PrinterErrorCode.connectionTimeout,
        'Could not connect to ${printer.name}.',
        cause: e,
      );
    }

    if (!connected) {
      throw PrinterException(
        PrinterErrorCode.connectionTimeout,
        'Could not connect to ${printer.name}.',
      );
    }

    // Let the OS finish USB permission/claim handshaking before writes.
    await Future.delayed(const Duration(milliseconds: 500));
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    if (_connected) {
      try {
        await _usbPrinter.close();
      } catch (_) {
        // Best-effort; device may already be gone.
      }
    }
    _connected = false;
  }

  @override
  Future<bool> isConnected() async => _connected;

  @override
  Future<void> printImage(
    Uint8List imageBytes, {
    required int width,
    required int height,
    PrinterCalibration calibration = const PrinterCalibration(),
    int copies = 1,
  }) async {
    if (!_connected) {
      throw const PrinterException(
        PrinterErrorCode.notConnected,
        'Printer is not connected. Please connect a printer before printing.',
      );
    }

    final zpl = _encoder.buildLabelZpl(
      pixels: imageBytes,
      width: width,
      height: height,
      calibration: calibration,
      copies: copies,
    );

    await _write(zpl);
  }

  Future<void> printRawZpl(String zpl) async {
    if (!_connected) {
      throw const PrinterException(
        PrinterErrorCode.notConnected,
        'Printer is not connected. Please connect a printer before printing.',
      );
    }
    await _write(zpl);
  }

  Future<void> _write(String zpl) async {
    try {
      // Let the connection settle before the first chunk goes out.
      await Future.delayed(const Duration(milliseconds: 200));

      await ChunkedWriter.write(
        utf8.encode(zpl),
        (chunk) async {
          final sent = await _usbPrinter.write(Uint8List.fromList(chunk));
          if (sent != true) {
            throw const PrinterException(
              PrinterErrorCode.communicationError,
              'Failed to send label data to the printer.',
            );
          }
        },
        chunkSize: 1024,
        delayMs: 10,
      );

      // Give the printer time to flush its buffer and finish printing
      // before this call returns (and the caller e.g. disconnects).
      await Future.delayed(const Duration(milliseconds: 2000));
    } on PrinterException {
      rethrow;
    } catch (e) {
      throw PrinterException(
        PrinterErrorCode.communicationError,
        'Failed to send label data to the printer.',
        cause: e,
      );
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
  }
}
