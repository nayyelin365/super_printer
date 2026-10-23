package app.sks.client.drago_usb_printer.tools

import android.hardware.usb.UsbDevice
import io.flutter.plugin.common.MethodCall


/// Author       : liyufeng
/// Date         : 14:27
/// Description  : 
object MethodCallParser {

    fun parseDevice(call: MethodCall): ExUsbDevice? {
        val vendorId = call.argument<Int>("vendorId")
        val productId = call.argument<Int>("productId")
        val serialNumber = call.argument<String>("serialNumber")
        var usbDevice: ExUsbDevice? = null
        if (vendorId != null && productId != null) {
            val matchedDevice = UsbDeviceHelper.instance.matchUsbDevice(
                vendorId = vendorId,
                productId = productId,
                serialNumber = serialNumber,
            )
            matchedDevice?.let {
                usbDevice = ExUsbDevice(
                    deviceId = deviceKey(vendorId, productId, serialNumber),
                    usbDevice = it,
                )
            }
        }
        return usbDevice
    }

    fun parseDeviceId(call: MethodCall): String {
        val vendorId = call.argument<Int>("vendorId")
        val productId = call.argument<Int>("productId")
        val serialNumber = call.argument<String>("serialNumber")
        return deviceKey(vendorId, productId, serialNumber)
    }

    /// Cache key for [DragoUsbPrinterPlugin.usbConnCache] — includes the
    /// serial number (when given) so two same-model printers' connections
    /// are cached separately instead of colliding under the same
    /// vendorId-productId key.
    private fun deviceKey(vendorId: Int?, productId: Int?, serialNumber: String?): String {
        val base = "$vendorId - $productId"
        return if (serialNumber.isNullOrEmpty()) base else "$base - $serialNumber"
    }

}

class ExUsbDevice(
    var deviceId: String,
    var usbDevice: UsbDevice
)