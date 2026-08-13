import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/printer/bluetooth_label_printer.dart';
import '../../../core/printer/label_printer.dart';
import '../../../core/printer/models/connection_type.dart';
import '../../../core/printer/models/printer_config.dart';
import '../../../core/printer/models/printer_device.dart';
import '../../../core/printer/models/printer_model.dart';
import '../../../core/printer/printer_exceptions.dart';
import '../../../core/printer/printer_registry.dart';
import '../../../core/printer/printer_session_controller.dart';
import '../../../core/printer/usb_label_printer.dart';
import '../../../core/printer/zpl_encoder.dart';

enum DeviceConnectState { idle, connecting, connected, failed }

class PrinterSetupState {
  const PrinterSetupState({
    this.name = '',
    this.connectionType = PrinterConnectionType.bluetooth,
    this.printerModelId = 'other_printer',
    this.dpi = 300,
    this.labelSizeId = '3x2',
    this.isSearching = false,
    this.discoveredDevices = const [],
    this.selectedDevice,
    this.connectState = DeviceConnectState.idle,
    this.errorMessage,
    this.isSaving = false,
    this.saved = false,
    this.isTestPrinting = false,
    this.testPrintMessage,
  });

  final String name;
  final PrinterConnectionType connectionType;
  final String printerModelId;
  final int dpi;
  final String labelSizeId;

  final bool isSearching;
  final List<PrinterDevice> discoveredDevices;
  final PrinterDevice? selectedDevice;
  final DeviceConnectState connectState;

  final String? errorMessage;
  final bool isSaving;
  final bool saved;

  final bool isTestPrinting;
  final String? testPrintMessage;

  bool get canSave =>
      name.trim().isNotEmpty && connectState == DeviceConnectState.connected;

  PrinterSetupState copyWith({
    String? name,
    PrinterConnectionType? connectionType,
    String? printerModelId,
    int? dpi,
    String? labelSizeId,
    bool? isSearching,
    List<PrinterDevice>? discoveredDevices,
    PrinterDevice? Function()? selectedDevice,
    DeviceConnectState? connectState,
    String? Function()? errorMessage,
    bool? isSaving,
    bool? saved,
    bool? isTestPrinting,
    String? Function()? testPrintMessage,
  }) {
    return PrinterSetupState(
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      printerModelId: printerModelId ?? this.printerModelId,
      dpi: dpi ?? this.dpi,
      labelSizeId: labelSizeId ?? this.labelSizeId,
      isSearching: isSearching ?? this.isSearching,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      selectedDevice:
          selectedDevice != null ? selectedDevice() : this.selectedDevice,
      connectState: connectState ?? this.connectState,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isSaving: isSaving ?? this.isSaving,
      saved: saved ?? this.saved,
      isTestPrinting: isTestPrinting ?? this.isTestPrinting,
      testPrintMessage:
          testPrintMessage != null ? testPrintMessage() : this.testPrintMessage,
    );
  }
}

class PrinterSetupController extends StateNotifier<PrinterSetupState> {
  PrinterSetupController(this._ref, PrinterConfig? existing)
      : super(
          existing == null
              ? const PrinterSetupState()
              : PrinterSetupState(
                  name: existing.name,
                  connectionType: existing.connectionType,
                  printerModelId: existing.printerModelId,
                  dpi: existing.dpi,
                  labelSizeId: existing.labelSizeId,
                ),
        ) {
    _existingId = existing?.id;
  }

  final Ref _ref;
  String? _existingId;
  LabelPrinter? _pendingPrinter;
  final ZplEncoder _encoder = const ZplEncoder();

  void setName(String value) => state = state.copyWith(name: value);

  void setConnectionType(PrinterConnectionType type) {
    _pendingPrinter?.dispose();
    _pendingPrinter = null;
    state = state.copyWith(
      connectionType: type,
      discoveredDevices: [],
      selectedDevice: () => null,
      connectState: DeviceConnectState.idle,
    );
  }

  void setPrinterModel(String id) => state = state.copyWith(printerModelId: id);

  void setDpi(int dpi) => state = state.copyWith(dpi: dpi);

  void setLabelSize(String id) => state = state.copyWith(labelSizeId: id);

  Future<void> search() async {
    state = state.copyWith(
      isSearching: true,
      discoveredDevices: [],
      errorMessage: () => null,
    );
    final scanner = PrinterRegistry.create(state.connectionType);
    try {
      final devices = await scanner.discoverPrinters();
      state = state.copyWith(isSearching: false, discoveredDevices: devices);
    } on PrinterException catch (e) {
      state = state.copyWith(isSearching: false, errorMessage: () => e.message);
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: () => 'Unable to search for printers.',
      );
    } finally {
      await scanner.dispose();
    }
  }

  Future<void> connectTo(PrinterDevice device) async {
    _pendingPrinter?.dispose();
    _pendingPrinter = PrinterRegistry.create(state.connectionType);

    state = state.copyWith(
      selectedDevice: () => device,
      connectState: DeviceConnectState.connecting,
      errorMessage: () => null,
      name: state.name.trim().isEmpty ? device.name : state.name,
    );

    try {
      await _pendingPrinter!.connect(device);
      state = state.copyWith(connectState: DeviceConnectState.connected);
    } on PrinterException catch (e) {
      state = state.copyWith(
        connectState: DeviceConnectState.failed,
        errorMessage: () => e.message,
      );
    } catch (e) {
      state = state.copyWith(
        connectState: DeviceConnectState.failed,
        errorMessage: () => 'Could not connect to the printer.',
      );
    }
  }

  Future<void> testPrint() async {
    final printer = _pendingPrinter;
    if (printer == null || state.connectState != DeviceConnectState.connected) {
      state = state.copyWith(
        testPrintMessage: () =>
            'Printer is not connected. Please connect a printer before printing.',
      );
      return;
    }

    state = state.copyWith(isTestPrinting: true, testPrintMessage: () => null);
    final zpl = _encoder.buildTestLabelZpl(
      printerName: state.name.isEmpty
          ? state.selectedDevice?.name ?? 'Printer'
          : state.name,
      labelSize: PrinterConfig(
        id: '',
        name: '',
        connectionType: state.connectionType,
        printerModelId: state.printerModelId,
        labelSizeId: state.labelSizeId,
      ).labelSize.displayName,
      dpi: state.dpi,
      connectionType: state.connectionType.label,
    );

    try {
      if (printer is BluetoothLabelPrinter) {
        await printer.printRawZpl(zpl);
      } else if (printer is UsbLabelPrinter) {
        await printer.printRawZpl(zpl);
      }
      state = state.copyWith(
        isTestPrinting: false,
        testPrintMessage: () => '1 test label printed successfully.',
      );
    } on PrinterException catch (e) {
      state = state.copyWith(
        isTestPrinting: false,
        testPrintMessage: () => e.message,
      );
    } catch (_) {
      state = state.copyWith(
        isTestPrinting: false,
        testPrintMessage: () => 'Test print failed. Please try again.',
      );
    }
  }

  Future<bool> save() async {
    final device = state.selectedDevice;
    final printer = _pendingPrinter;
    if (device == null ||
        printer == null ||
        state.connectState != DeviceConnectState.connected) {
      state = state.copyWith(
        errorMessage: () => 'Connect a printer before saving.',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, errorMessage: () => null);

    final config = PrinterConfig(
      id: _existingId ?? const Uuid().v4(),
      name: state.name.trim().isEmpty ? device.name : state.name.trim(),
      connectionType: state.connectionType,
      printerModelId: state.printerModelId,
      bluetoothAddress:
          state.connectionType == PrinterConnectionType.bluetooth
              ? device.address
              : null,
      usbVendorId: device.usbVendorId,
      usbProductId: device.usbProductId,
      usbDeviceName: device.usbDeviceName,
      dpi: state.dpi,
      labelSizeId: state.labelSizeId,
    );

    await _ref.read(printerSessionProvider.notifier).adopt(config, printer);
    _pendingPrinter = null;
    state = state.copyWith(isSaving: false, saved: true);
    return true;
  }

  @override
  void dispose() {
    _pendingPrinter?.dispose();
    super.dispose();
  }
}

final printerSetupControllerProvider = StateNotifierProvider.autoDispose<
    PrinterSetupController, PrinterSetupState>((ref) {
  final existing = ref.watch(printerSessionProvider).config;
  return PrinterSetupController(ref, existing);
});

/// Static catalog providers, exposed so the settings UI doesn't import
/// core model files directly for enumeration.
final printerModelCatalogProvider = Provider<List<PrinterModel>>(
  (ref) => PrinterModel.catalog,
);
