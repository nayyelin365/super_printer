import 'connection_type.dart';
import 'label_size.dart';
import 'printer_calibration.dart';
import 'printer_device.dart';
import 'printer_model.dart';

/// Persisted configuration for a printer the user has set up.
///
/// This is intentionally separate from [PrinterDevice] (a transient scan
/// result): it stores the durable device identifier needed to reconnect
/// (Bluetooth MAC / BLE remote id, or USB vendor+product id) rather than
/// just a friendly display name.
class PrinterConfig {
  const PrinterConfig({
    required this.id,
    required this.name,
    required this.connectionType,
    required this.printerModelId,
    this.bluetoothAddress,
    this.usbVendorId,
    this.usbProductId,
    this.usbDeviceName,
    this.usbSerialNumber,
    this.dpi = 300,
    this.labelSizeId = '3x2',
    this.isDefault = true,
    this.calibration = const PrinterCalibration(),
  });

  final String id;
  final String name;
  final PrinterConnectionType connectionType;
  final String printerModelId;

  final String? bluetoothAddress;
  final int? usbVendorId;
  final int? usbProductId;
  final String? usbDeviceName;

  /// The saved printer's USB serial number, when the device exposed one —
  /// the one identifier that's actually unique per physical unit (unlike
  /// [usbVendorId]/[usbProductId], identical across every printer of the
  /// same model). Lets two saved configs for two identical-model printers
  /// (e.g. one dedicated to 3x2 labels, one to 3x6) each reconnect to the
  /// correct physical unit instead of whichever one Android happens to
  /// enumerate first.
  final String? usbSerialNumber;

  final int dpi;
  final String labelSizeId;
  final bool isDefault;
  final PrinterCalibration calibration;

  PrinterModel get printerModel => PrinterModel.fromId(printerModelId);
  LabelSize get labelSize => LabelSize.fromId(labelSizeId);

  /// The device identifier used to reconnect, independent of connection type.
  String get deviceAddress => switch (connectionType) {
        PrinterConnectionType.bluetooth => bluetoothAddress ?? '',
        PrinterConnectionType.usb => '${usbVendorId ?? 0}:${usbProductId ?? 0}',
      };

  PrinterDevice toPrinterDevice() => PrinterDevice(
        name: name,
        address: deviceAddress,
        connectionType: connectionType,
        usbVendorId: usbVendorId,
        usbProductId: usbProductId,
        usbDeviceName: usbDeviceName,
        usbSerialNumber: usbSerialNumber,
      );

  PrinterConfig copyWith({
    String? name,
    PrinterConnectionType? connectionType,
    String? printerModelId,
    String? bluetoothAddress,
    int? usbVendorId,
    int? usbProductId,
    String? usbDeviceName,
    String? usbSerialNumber,
    int? dpi,
    String? labelSizeId,
    bool? isDefault,
    PrinterCalibration? calibration,
  }) {
    return PrinterConfig(
      id: id,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      printerModelId: printerModelId ?? this.printerModelId,
      bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
      usbVendorId: usbVendorId ?? this.usbVendorId,
      usbProductId: usbProductId ?? this.usbProductId,
      usbDeviceName: usbDeviceName ?? this.usbDeviceName,
      usbSerialNumber: usbSerialNumber ?? this.usbSerialNumber,
      dpi: dpi ?? this.dpi,
      labelSizeId: labelSizeId ?? this.labelSizeId,
      isDefault: isDefault ?? this.isDefault,
      calibration: calibration ?? this.calibration,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'connectionType': connectionType.name,
        'printerModelId': printerModelId,
        'bluetoothAddress': bluetoothAddress,
        'usbVendorId': usbVendorId,
        'usbProductId': usbProductId,
        'usbDeviceName': usbDeviceName,
        'usbSerialNumber': usbSerialNumber,
        'dpi': dpi,
        'labelSizeId': labelSizeId,
        'isDefault': isDefault,
        'calibration': calibration.toJson(),
      };

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    return PrinterConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      connectionType: PrinterConnectionType.fromName(
        json['connectionType'] as String? ?? 'bluetooth',
      ),
      printerModelId: json['printerModelId'] as String? ?? 'other_printer',
      bluetoothAddress: json['bluetoothAddress'] as String?,
      usbVendorId: json['usbVendorId'] as int?,
      usbProductId: json['usbProductId'] as int?,
      usbDeviceName: json['usbDeviceName'] as String?,
      usbSerialNumber: json['usbSerialNumber'] as String?,
      dpi: json['dpi'] as int? ?? 300,
      labelSizeId: json['labelSizeId'] as String? ?? LabelSize.threeByTwo.id,
      isDefault: json['isDefault'] as bool? ?? true,
      calibration: json['calibration'] == null
          ? const PrinterCalibration()
          : PrinterCalibration.fromJson(
              json['calibration'] as Map<String, dynamic>,
            ),
    );
  }
}
