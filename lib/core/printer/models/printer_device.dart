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
    this.usbSerialNumber,
    this.rssi,
  });

  final String name;
  final String address;
  final PrinterConnectionType connectionType;
  final int? usbVendorId;
  final int? usbProductId;
  final String? usbDeviceName;

  /// The physical unit's USB serial number — unlike [usbVendorId]/
  /// [usbProductId] (identical across every printer of the same model),
  /// this is actually unique per device, and survives being replugged
  /// into a different port or the app/device rebooting. Null when the
  /// OS/device doesn't expose one; callers then fall back to matching by
  /// vendor+product id only, same as before this field existed — so two
  /// same-model printers become indistinguishable again in that case, not
  /// an error.
  final String? usbSerialNumber;
  final int? rssi;

  String get subtitle => switch (connectionType) {
        PrinterConnectionType.bluetooth => address,
        PrinterConnectionType.usb => usbSerialNumber == null
            ? 'VID: ${_hex(usbVendorId)}  PID: ${_hex(usbProductId)}'
            : 'VID: ${_hex(usbVendorId)}  PID: ${_hex(usbProductId)}  S/N: $usbSerialNumber',
      };

  static String _hex(int? value) =>
      value == null ? '—' : '0x${value.toRadixString(16).toUpperCase()}';

  /// Two USB devices are the same physical unit only when their serial
  /// numbers match (when both have one) — vendor+product id alone is NOT
  /// enough to tell two printers of the same model apart. Without a
  /// serial number on either side, this falls back to the old
  /// address-only comparison (every same-model printer looks identical,
  /// same as before serial numbers were tracked at all).
  @override
  bool operator ==(Object other) {
    if (other is! PrinterDevice ||
        other.address != address ||
        other.connectionType != connectionType) {
      return false;
    }
    if (usbSerialNumber != null && other.usbSerialNumber != null) {
      return usbSerialNumber == other.usbSerialNumber;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(address, connectionType);
}
