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
      );

  PrinterConfig copyWith({
    String? name,
    PrinterConnectionType? connectionType,
    String? printerModelId,
    String? bluetoothAddress,
    int? usbVendorId,
    int? usbProductId,
    String? usbDeviceName,
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
