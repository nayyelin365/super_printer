import 'connection_type.dart';

/// A printer discovered during a Bluetooth or USB scan, or reconstructed
/// from a saved [PrinterConfig].
///
/// For Bluetooth, [address] holds the MAC address (or BLE remote id on
/// platforms that don't expose a MAC, e.g. iOS/macOS). For USB, [address]
/// holds `vendorId:productId` and [usbDeviceName] holds the OS device path.
class PrinterDevice {
  const PrinterDevice({
    required this.name,
    required this.address,
    required this.connectionType,
    this.usbVendorId,
    this.usbProductId,
    this.usbDeviceName,
    this.rssi,
  });

  final String name;
  final String address;
  final PrinterConnectionType connectionType;
  final int? usbVendorId;
  final int? usbProductId;
  final String? usbDeviceName;
  final int? rssi;

  String get subtitle => switch (connectionType) {
        PrinterConnectionType.bluetooth => address,
        PrinterConnectionType.usb =>
          'VID: ${_hex(usbVendorId)}  PID: ${_hex(usbProductId)}',
      };

  static String _hex(int? value) =>
      value == null ? '—' : '0x${value.toRadixString(16).toUpperCase()}';

  @override
  bool operator ==(Object other) =>
      other is PrinterDevice &&
      other.address == address &&
      other.connectionType == connectionType;

  @override
  int get hashCode => Object.hash(address, connectionType);
}
