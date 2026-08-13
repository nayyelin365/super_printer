/// User-facing printer error categories. UI layers should present
/// [PrinterException.message]; raw platform exceptions must never reach
/// the user directly — catch them at the adapter boundary and wrap them
/// here, logging the technical detail via [cause].
class PrinterException implements Exception {
  const PrinterException(this.code, this.message, {this.cause});

  final PrinterErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'PrinterException(${code.name}): $message';
}

enum PrinterErrorCode {
  bluetoothUnavailable,
  bluetoothPermissionDenied,
  deviceNotFound,
  usbUnavailable,
  notConnected,
  connectionFailed,
  connectionTimeout,
  printerBusy,
  printTimeout,
  invalidLabelSize,
  invalidBarcode,
  invalidQuantity,
  invalidAmount,
  communicationError,
}
