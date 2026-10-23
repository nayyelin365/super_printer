import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class DragoUsbPrinter {
  static const MethodChannel _channel =
      const MethodChannel('drago_usb_printer');

  int vendorId = 0;
  int productId = 0;

  /// The physical device's USB serial number — set by [connect], then
  /// threaded through every subsequent call for this instance (close,
  /// write, ...) so they all keep addressing the same specific unit, not
  /// just "a" device with this vendorId/productId. Null when the caller
  /// didn't have one (falls back to the old vendorId/productId-only
  /// behavior) or the device/OS doesn't expose one.
  String? serialNumber;

  /// [getUSBDeviceList]
  /// get list of available usb device on android. Each entry now also
  /// carries a `serialNumber` (may be null) — the one identifier that's
  /// actually unique per physical unit, unlike vendorId/productId which
  /// are identical across every printer of the same model.
  static Future<List<Map<String, dynamic>>> getUSBDeviceList() async {
    if (Platform.isAndroid) {
      List<dynamic> devices = await _channel.invokeMethod('getUSBDeviceList');
      print(devices);
      var result = devices
          .cast<Map<dynamic, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return result;
    } else {
      return <Map<String, dynamic>>[];
    }
  }

  /// [connect]
  /// Connects to a printer by vendorId and productId, and — when
  /// [serialNumber] is given — only to the one physical device whose own
  /// serial number matches it. Without a serial number, this behaves
  /// exactly as before: whichever currently-attached device with that
  /// vendorId/productId Android happens to return first.
  Future<bool?> connect(int vendorId, int productId, {String? serialNumber}) async {
    this.vendorId = vendorId;
    this.productId = productId;
    this.serialNumber = serialNumber;

    Map<String, dynamic> params = {
      "vendorId": vendorId,
      "productId": productId,
      if (serialNumber != null) "serialNumber": serialNumber,
    };
    final bool? result = await _channel.invokeMethod('connect', params);
    print('connected $result');
    return result;
  }

  /// [close]
  /// close the connection after print with usb printer
  Future<bool?> close() async {
    Map<String, dynamic> params = {
      "vendorId": vendorId,
      "productId": productId,
      if (serialNumber != null) "serialNumber": serialNumber,
    };
    final bool? result = await _channel.invokeMethod('disconnect', params);
    return result;
  }

  /// [printText]
  /// print text
  Future<bool?> printText(String text) async {
    Map<String, dynamic> params = {
      "text": text,
      "vendorId": vendorId,
      "productId": productId,
      if (serialNumber != null) "serialNumber": serialNumber,
    };
    final bool? result = await _channel.invokeMethod('printText', params);
    return result;
  }

  /// [printRawText]
  /// print raw text
  Future<bool?> printRawText(String text) async {
    Map<String, dynamic> params = {
      "raw": text,
      "vendorId": vendorId,
      "productId": productId,
      if (serialNumber != null) "serialNumber": serialNumber,
    };
    final bool? result = await _channel.invokeMethod('printRawText', params);
    return result;
  }

  /// [write]
  /// write data byte
  Future<bool?> write(Uint8List data) async {
    Map<String, dynamic> params = {
      "data": data,
      "vendorId": vendorId,
      "productId": productId,
      if (serialNumber != null) "serialNumber": serialNumber,
    };
    final bool? result = await _channel.invokeMethod('write', params);
    return result;
  }
}
