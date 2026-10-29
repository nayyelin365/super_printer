import 'dart:convert';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'label_printer.dart';
import 'models/connection_type.dart';
import 'models/printer_calibration.dart';
import 'models/printer_device.dart';
import 'printer_exceptions.dart';
import 'tspl_encoder.dart';
import 'zpl_encoder.dart';

/// Classic Bluetooth (SPP) transport for Zebra printers, built on
/// `print_bluetooth_thermal`.
///
/// Zebra desktop printers (ZD220/ZD230/ZD420/ZD421, etc.) pair over classic
/// Bluetooth rather than BLE, and are addressed by MAC — matching the
/// "Printer MAC Address" field in the settings UI. Discovery lists already
/// system-paired devices rather than doing a live GATT scan, since that's
/// how these printers are set up in practice (pair once via OS Bluetooth
/// settings, then connect from the app by address).
class BluetoothLabelPrinter implements LabelPrinter {
  final ZplEncoder _zplEncoder = const ZplEncoder();
  final TsplEncoder _tsplEncoder = const TsplEncoder();
  bool _connected = false;

  @override
  Future<List<PrinterDevice>> discoverPrinters() async {
    await _ensureBluetoothReady();

    try {
      final paired = await PrintBluetoothThermal.pairedBluetooths;
      return paired
          .map((d) => PrinterDevice(
                name: d.name.isEmpty ? d.macAdress : d.name,
                address: d.macAdress,
                connectionType: PrinterConnectionType.bluetooth,
              ))
          .toList();
    } catch (e) {
      throw PrinterException(
        PrinterErrorCode.bluetoothUnavailable,
        'Unable to search for Bluetooth printers.',
        cause: e,
      );
    }
  }

  Future<void> _ensureBluetoothReady() async {
    // print_bluetooth_thermal only *checks* BLUETOOTH_CONNECT (Android
    // 12+); it never triggers the OS permission dialog itself, so we have
    // to request it before checking, or a first-time user is never
    // actually prompted — the app would just report "denied" forever.
    // BLUETOOTH_SCAN is also required: the plugin's connect() internally
    // calls BluetoothAdapter.cancelDiscovery(), which needs it even though
    // this app never runs its own discovery scan.
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    final allGranted = statuses.values.every((s) => s.isGranted);
    if (!allGranted) {
      final permanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
      throw PrinterException(
        PrinterErrorCode.bluetoothPermissionDenied,
        permanentlyDenied
            ? 'Bluetooth permission was denied. Please enable "Nearby devices" for this app in Settings.'
            : 'Bluetooth permission is required to connect to the printer.',
      );
    }

    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      throw const PrinterException(
        PrinterErrorCode.bluetoothUnavailable,
        'Bluetooth is turned off. Please enable Bluetooth and try again.',
      );
    }
  }

  @override
  Future<void> connect(PrinterDevice printer) async {
    if (printer.connectionType != PrinterConnectionType.bluetooth) {
      throw const PrinterException(
        PrinterErrorCode.connectionFailed,
        'Not a Bluetooth device.',
      );
    }

    await _ensureBluetoothReady();
    await disconnect();

    bool connected;
    try {
      connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.address,
      );
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
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {
      // Best-effort; device may already be gone.
    }
    _connected = false;
  }

  @override
  Future<bool> isConnected() async {
    if (!_connected) return false;
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> printImage(
    Uint8List imageBytes, {
    required int width,
    required int height,
    required double labelWidthInches,
    required double labelHeightInches,
    bool useTspl = false,
    PrinterCalibration calibration = const PrinterCalibration(),
    int copies = 1,
  }) async {
    if (!await isConnected()) {
      throw const PrinterException(
        PrinterErrorCode.notConnected,
        'Printer is not connected. Please connect a printer before printing.',
      );
    }

    final bytes = useTspl
        ? _tsplEncoder.buildLabelTspl(
            pixels: imageBytes,
            width: width,
            height: height,
            labelWidthInches: labelWidthInches,
            labelHeightInches: labelHeightInches,
            calibration: calibration,
            copies: copies,
          )
        : utf8.encode(_zplEncoder.buildLabelZpl(
            pixels: imageBytes,
            width: width,
            height: height,
            calibration: calibration,
            copies: copies,
          ));

    await _write(bytes);
  }

  Future<void> printRawZpl(String zpl) async {
    if (!await isConnected()) {
      throw const PrinterException(
        PrinterErrorCode.notConnected,
        'Printer is not connected. Please connect a printer before printing.',
      );
    }
    await _write(utf8.encode(zpl));
  }

  Future<void> printRawTspl(List<int> tspl) async {
    if (!await isConnected()) {
      throw const PrinterException(
        PrinterErrorCode.notConnected,
        'Printer is not connected. Please connect a printer before printing.',
      );
    }
    await _write(tspl);
  }

  Future<void> _write(List<int> data) async {
    try {
      // Deliberately NOT using ChunkedWriter here: print_bluetooth_thermal's
      // native `writebytes` handler prepends a literal "\n" byte to every
      // single call it receives (see its Android source), and itself
      // already re-chunks into safe, flushed 16KB writes internally. If we
      // also chunk on the Dart side, every chunk boundary injects an extra
      // stray byte into the stream — invisible to ZPL (whitespace-tolerant
      // ASCII hex) but fatal to TSPL's `BITMAP` command, whose binary
      // payload must be exactly the declared byte count: a few stray bytes
      // partway through desyncs the printer's parser and can print as a
      // solid black block. Sending the whole job in one call means at most
      // one spurious leading "\n" ever exists, landing before the first
      // command line, which every TSPL/ZPL parser tolerates as harmless
      // leading whitespace.
      final sent = await PrintBluetoothThermal.writeBytes(data.toList());
      if (!sent) {
        throw const PrinterException(
          PrinterErrorCode.communicationError,
          'Failed to send label data to the printer.',
        );
      }
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
