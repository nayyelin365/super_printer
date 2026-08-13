import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'label_printer.dart';
import 'models/printer_calibration.dart';
import 'models/printer_device.dart';
import 'models/connection_type.dart';
import 'printer_exceptions.dart';
import 'zpl_encoder.dart';

/// Bluetooth Low Energy transport for Zebra printers, built on
/// `flutter_blue_plus`.
///
/// Zebra printers that expose print data over BLE do so through a
/// vendor-specific GATT characteristic that accepts raw ZPL bytes. Since the
/// exact UUID varies by firmware/model, this implementation discovers all
/// services after connecting and writes to the first characteristic that
/// supports `write`/`writeWithoutResponse` — the same strategy used by
/// generic "BLE UART bridge" integrations. Known Zebra UUIDs are tried
/// first for reliability.
class BluetoothLabelPrinter implements LabelPrinter {
  BluetoothLabelPrinter({this.scanTimeout = const Duration(seconds: 8)});

  final Duration scanTimeout;
  final ZplEncoder _encoder = const ZplEncoder();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  /// Common vendor UUIDs known to be used for raw print data on Zebra /
  /// generic thermal BLE printers. Tried in order before falling back to a
  /// generic writable-characteristic search.
  static const _preferredServiceUuids = <String>[
    '38eb4a80-c570-11e3-9507-0002a5d5c51b', // Zebra print service (common)
    '49535343-fe7d-4ae5-8fa9-9fafd205e455', // Generic UART-style bridge
  ];

  @override
  Future<List<PrinterDevice>> discoverPrinters() async {
    await _ensurePermissions();

    if (!await FlutterBluePlus.isSupported) {
      throw const PrinterException(
        PrinterErrorCode.bluetoothUnavailable,
        'Bluetooth is not supported on this device.',
      );
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw const PrinterException(
        PrinterErrorCode.bluetoothUnavailable,
        'Bluetooth is turned off. Please enable Bluetooth and try again.',
      );
    }

    final found = <String, PrinterDevice>{};

    // Already-bonded/system-connected devices show up immediately.
    for (final d in FlutterBluePlus.connectedDevices) {
      found[d.remoteId.str] = PrinterDevice(
        name: d.platformName.isEmpty ? 'Unknown device' : d.platformName,
        address: d.remoteId.str,
        connectionType: PrinterConnectionType.bluetooth,
      );
    }

    final completer = Completer<void>();
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;
        if (name.isEmpty) continue;
        found[r.device.remoteId.str] = PrinterDevice(
          name: name,
          address: r.device.remoteId.str,
          connectionType: PrinterConnectionType.bluetooth,
          rssi: r.rssi,
        );
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: scanTimeout);
      await FlutterBluePlus.isScanning.where((s) => s == false).first;
    } catch (e) {
      throw PrinterException(
        PrinterErrorCode.bluetoothUnavailable,
        'Unable to search for Bluetooth printers.',
        cause: e,
      );
    } finally {
      await sub.cancel();
      if (!completer.isCompleted) completer.complete();
    }

    return found.values.toList();
  }

  Future<void> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final denied = statuses.values.any(
      (s) => s.isPermanentlyDenied || s.isDenied,
    );
    // Some platforms (desktop/web) don't implement these permissions; treat
    // "not applicable" results as fine and only fail on explicit denial.
    if (denied &&
        statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied)) {
      final hasAnyGranted = statuses.values.any((s) => s.isGranted);
      if (!hasAnyGranted) {
        throw const PrinterException(
          PrinterErrorCode.bluetoothPermissionDenied,
          'Bluetooth permission was denied. Please enable it in Settings.',
        );
      }
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

    await disconnect();

    final device = BluetoothDevice.fromId(printer.address);
    _device = device;

    try {
      await device.connect(
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );
    } catch (e) {
      _device = null;
      throw PrinterException(
        PrinterErrorCode.connectionTimeout,
        'Could not connect to ${printer.name}.',
        cause: e,
      );
    }

    _connectionSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _writeCharacteristic = null;
      }
    });

    try {
      final services = await device.discoverServices();
      _writeCharacteristic = _pickWriteCharacteristic(services);
    } catch (e) {
      throw PrinterException(
        PrinterErrorCode.communicationError,
        'Connected to ${printer.name}, but could not prepare it for printing.',
        cause: e,
      );
    }

    if (_writeCharacteristic == null) {
      throw const PrinterException(
        PrinterErrorCode.communicationError,
        'This printer does not expose a writable print channel.',
      );
    }
  }

  BluetoothCharacteristic? _pickWriteCharacteristic(
    List<BluetoothService> services,
  ) {
    for (final preferred in _preferredServiceUuids) {
      for (final service in services) {
        if (service.uuid.str128.toLowerCase() != preferred) continue;
        for (final c in service.characteristics) {
          if (c.properties.write || c.properties.writeWithoutResponse) {
            return c;
          }
        }
      }
    }
    for (final service in services) {
      for (final c in service.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) {
          return c;
        }
      }
    }
    return null;
  }

  @override
  Future<void> disconnect() async {
    await _connectionSub?.cancel();
    _connectionSub = null;
    _writeCharacteristic = null;
    final device = _device;
    _device = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // Best-effort; device may already be gone.
      }
    }
  }

  @override
  Future<bool> isConnected() async {
    final device = _device;
    if (device == null) return false;
    return device.isConnected;
  }

  @override
  Future<void> printImage(
    Uint8List imageBytes, {
    required int width,
    required int height,
    PrinterCalibration calibration = const PrinterCalibration(),
  }) async {
    final characteristic = _writeCharacteristic;
    if (characteristic == null || !(await isConnected())) {
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

    await _writeChunked(characteristic, utf8.encode(zpl));
  }

  Future<void> printRawZpl(String zpl) async {
    final characteristic = _writeCharacteristic;
    if (characteristic == null || !(await isConnected())) {
      throw const PrinterException(
        PrinterErrorCode.notConnected,
        'Printer is not connected. Please connect a printer before printing.',
      );
    }
    await _writeChunked(characteristic, utf8.encode(zpl));
  }

  Future<void> _writeChunked(
    BluetoothCharacteristic characteristic,
    List<int> data,
  ) async {
    const chunkSize = 180; // safe below typical negotiated BLE MTU
    final withoutResponse = characteristic.properties.writeWithoutResponse &&
        !characteristic.properties.write;
    try {
      for (var offset = 0; offset < data.length; offset += chunkSize) {
        final end =
            (offset + chunkSize < data.length) ? offset + chunkSize : data.length;
        await characteristic.write(
          data.sublist(offset, end),
          withoutResponse: withoutResponse,
        );
      }
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
    await FlutterBluePlus.stopScan();
    await disconnect();
  }
}
