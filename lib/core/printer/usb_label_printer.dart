import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

import 'label_printer.dart';
import 'models/connection_type.dart';
import 'models/printer_calibration.dart';
import 'models/printer_device.dart';
import 'printer_exceptions.dart';
import 'zpl_encoder.dart';

/// USB transport for Zebra printers, built on `usb_serial`.
///
/// Zebra desktop printers (ZD220/ZD230/ZD420/ZD421, etc.) enumerate as a
/// USB-serial (CDC/vendor-class) device and accept raw ZPL over that port.
/// `usb_serial` only supports Android; other desktop platforms would need a
/// separate raw-USB or OS print-spooler adapter behind this same
/// [LabelPrinter] interface, so callers never need to know the difference.
class UsbLabelPrinter implements LabelPrinter {
  final ZplEncoder _encoder = const ZplEncoder();
  UsbPort? _port;
  UsbDevice? _device;

  /// The currently connected device, if any. Exposed so the printer
  /// settings UI can display the active USB identifiers.
  UsbDevice? get connectedDevice => _device;

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
      final devices = await UsbSerial.listDevices();
      return devices
          .map((d) => PrinterDevice(
                name: (d.productName?.isNotEmpty ?? false)
                    ? d.productName!
                    : d.deviceName,
                address: '${d.vid ?? 0}:${d.pid ?? 0}',
                connectionType: PrinterConnectionType.usb,
                usbVendorId: d.vid,
                usbProductId: d.pid,
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

    final devices = await UsbSerial.listDevices();
    final match = devices.firstWhere(
      (d) => d.vid == printer.usbVendorId && d.pid == printer.usbProductId,
      orElse: () => throw const PrinterException(
        PrinterErrorCode.deviceNotFound,
        'The saved USB printer was not found. Check the cable and try again.',
      ),
    );

    final port = await match.create();
    if (port == null) {
      throw const PrinterException(
        PrinterErrorCode.connectionFailed,
        'Could not open a connection to the USB printer.',
      );
    }

    final opened = await port.open();
    if (!opened) {
      throw const PrinterException(
        PrinterErrorCode.connectionFailed,
        'Could not open a connection to the USB printer.',
      );
    }

    await port.setPortParameters(
      9600,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    _device = match;
    _port = port;
  }

  @override
  Future<void> disconnect() async {
    try {
      await _port?.close();
    } catch (_) {
      // Best-effort.
    }
    _port = null;
    _device = null;
  }

  @override
  Future<bool> isConnected() async => _port != null;

  @override
  Future<void> printImage(
    Uint8List imageBytes, {
    required int width,
    required int height,
    PrinterCalibration calibration = const PrinterCalibration(),
  }) async {
    final port = _port;
    if (port == null) {
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
    );

    try {
      await port.write(Uint8List.fromList(utf8.encode(zpl)));
    } catch (e) {
      throw PrinterException(
        PrinterErrorCode.communicationError,
        'Failed to send label data to the printer.',
        cause: e,
      );
    }
  }

  Future<void> printRawZpl(String zpl) async {
    final port = _port;
    if (port == null) {
      throw const PrinterException(
        PrinterErrorCode.notConnected,
        'Printer is not connected. Please connect a printer before printing.',
      );
    }
    try {
      await port.write(Uint8List.fromList(utf8.encode(zpl)));
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
