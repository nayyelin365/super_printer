import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_serial_communication/flutter_serial_communication.dart';
import 'package:flutter_serial_communication/models/device_info.dart';

import 'chunked_writer.dart';
import 'label_printer.dart';
import 'models/connection_type.dart';
import 'models/printer_calibration.dart';
import 'models/printer_device.dart';
import 'printer_exceptions.dart';
import 'zpl_encoder.dart';

/// USB transport for Zebra printers, built on `flutter_serial_communication`
/// (a maintained wrapper around mik3y/usb-serial-for-android).
///
/// Zebra desktop printers (ZD220/ZD230/ZD420/ZD421, etc.) enumerate as a
/// USB-serial device and accept raw ZPL over that port. This plugin only
/// supports Android; other desktop platforms would need a separate
/// raw-USB or OS print-spooler adapter behind this same [LabelPrinter]
/// interface, so callers never need to know the difference.
class UsbLabelPrinter implements LabelPrinter {
  final ZplEncoder _encoder = const ZplEncoder();
  final FlutterSerialCommunication _serial = FlutterSerialCommunication();
  DeviceInfo? _connectedDevice;

  /// The currently connected device, if any. Exposed so the printer
  /// settings UI can display the active USB identifiers.
  DeviceInfo? get connectedDevice => _connectedDevice;

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
      final devices = await _serial.getAvailableDevices();
      return devices
          .map((d) => PrinterDevice(
                name: d.productName.isNotEmpty ? d.productName : d.deviceName,
                address: '${d.vendorId ?? 0}:${d.productId ?? 0}',
                connectionType: PrinterConnectionType.usb,
                usbVendorId: d.vendorId,
                usbProductId: d.productId,
                usbDeviceName: d.deviceName,
              ))
          .toList();
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

    final devices = await _serial.getAvailableDevices();
    final match = devices.firstWhere(
      (d) =>
          d.vendorId == printer.usbVendorId &&
          d.productId == printer.usbProductId,
      orElse: () => throw const PrinterException(
        PrinterErrorCode.deviceNotFound,
        'The saved USB printer was not found. Check the cable and try again.',
      ),
    );

    bool connected;
    try {
      connected = await _serial.connect(match, 9600);
    } catch (e) {
      throw PrinterException(
        PrinterErrorCode.connectionFailed,
        'Could not open a connection to the USB printer.',
        cause: e,
      );
    }

    if (!connected) {
      throw const PrinterException(
        PrinterErrorCode.connectionFailed,
        'Could not open a connection to the USB printer.',
      );
    }

    _connectedDevice = match;
  }

  @override
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      try {
        await _serial.disconnect();
      } catch (_) {
        // Best-effort.
      }
    }
    _connectedDevice = null;
  }

  @override
  Future<bool> isConnected() async => _connectedDevice != null;

  @override
  Future<void> printImage(
    Uint8List imageBytes, {
    required int width,
    required int height,
    PrinterCalibration calibration = const PrinterCalibration(),
    int copies = 1,
  }) async {
    if (_connectedDevice == null) {
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
    if (_connectedDevice == null) {
      throw const PrinterException(
        PrinterErrorCode.notConnected,
        'Printer is not connected. Please connect a printer before printing.',
      );
    }
    await _write(zpl);
  }

  Future<void> _write(String zpl) async {
    try {
      await ChunkedWriter.write(
        utf8.encode(zpl),
        (chunk) async {
          final sent = await _serial.write(Uint8List.fromList(chunk));
          if (!sent) {
            throw const PrinterException(
              PrinterErrorCode.communicationError,
              'Failed to send label data to the printer.',
            );
          }
        },
        chunkSize: 512,
        delayMs: 20,
      );
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
