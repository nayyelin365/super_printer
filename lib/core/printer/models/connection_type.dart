enum PrinterConnectionType {
  bluetooth,
  usb;

  String get label => switch (this) {
        PrinterConnectionType.bluetooth => 'Bluetooth',
        PrinterConnectionType.usb => 'USB',
      };

  static PrinterConnectionType fromName(String name) =>
      PrinterConnectionType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => PrinterConnectionType.bluetooth,
      );
}
