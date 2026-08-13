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
    this.isEditingExisting = false,
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

  /// True when this screen was opened to edit an already-saved printer.
  /// Its device address is already known and persisted, so editing fields
  /// like name/DPI/label size shouldn't require re-discovering and
  /// re-connecting to the physical printer before Save is enabled.
  final bool isEditingExisting;

  bool get canSave =>
      name.trim().isNotEmpty &&
      (connectState == DeviceConnectState.connected ||
          (isEditingExisting && selectedDevice != null));

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
    bool? isEditingExisting,
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
      isEditingExisting: isEditingExisting ?? this.isEditingExisting,
    );
  }
}

class PrinterSetupController extends StateNotifier<PrinterSetupState> {
  factory PrinterSetupController(Ref ref, PrinterConfig? existing) {
    if (existing == null) {
      return PrinterSetupController._(ref, null, const PrinterSetupState());
    }

    // The printer's address is already known and persisted, so editing
    // metadata (name/DPI/label size) doesn't require a fresh connection.
    // If it also happens to be connected right now, reflect that so the
    // "Test Print" action keeps working against the live connection.
    final session = ref.read(printerSessionProvider);
    final alreadyConnected = session.config?.id == existing.id &&
        session.status == PrinterConnectionStatus.connected;

    return PrinterSetupController._(
      ref,
      existing,
      PrinterSetupState(
        name: existing.name,
        connectionType: existing.connectionType,
        printerModelId: existing.printerModelId,
        dpi: existing.dpi,
        labelSizeId: existing.labelSizeId,
        selectedDevice: existing.toPrinterDevice(),
        connectState: alreadyConnected
            ? DeviceConnectState.connected
            : DeviceConnectState.idle,
        isEditingExisting: true,
      ),
    );
  }

  PrinterSetupController._(this._ref, PrinterConfig? existing, PrinterSetupState initial)
      : super(initial) {
    _existingId = existing?.id;
    if (initial.connectState == DeviceConnectState.connected) {
      // Reuse the session's already-connected transport instead of opening
      // a second connection, so Test Print and Save act on the same link.
      _pendingPrinter = _ref.read(printerSessionProvider.notifier).printer;
      _reusingSessionPrinter = true;
    }
  }

  final Ref _ref;
  String? _existingId;
  LabelPrinter? _pendingPrinter;
  final ZplEncoder _encoder = const ZplEncoder();

  /// True while [_pendingPrinter] is actually the live session printer
  /// (reused, not opened by this screen) — it must never be disposed here.
  bool _reusingSessionPrinter = false;

  void _disposePendingPrinter() {
    if (!_reusingSessionPrinter) {
      _pendingPrinter?.dispose();
    }
    _pendingPrinter = null;
    _reusingSessionPrinter = false;
  }

  void setName(String value) => state = state.copyWith(name: value);

  void setConnectionType(PrinterConnectionType type) {
    _disposePendingPrinter();
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
    _disposePendingPrinter();
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
    if (device == null || !state.canSave) {
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

    final freshPrinter = _pendingPrinter;
    final sessionNotifier = _ref.read(printerSessionProvider.notifier);
    if (freshPrinter != null &&
        !_reusingSessionPrinter &&
        state.connectState == DeviceConnectState.connected) {
      // A new connection was made in this screen (new setup, or the user
      // re-picked a device while editing) — hand it off as the live printer.
      await sessionNotifier.adopt(config, freshPrinter);
      _pendingPrinter = null;
    } else {
      // Editing metadata only; the live connection (if any) is untouched.
      await sessionNotifier.updateConfig(config);
    }

    state = state.copyWith(isSaving: false, saved: true);
    return true;
  }

  @override
  void dispose() {
    _disposePendingPrinter();
    super.dispose();
  }
}

final printerSetupControllerProvider = StateNotifierProvider.autoDispose<
    PrinterSetupController, PrinterSetupState>((ref) {
  // Read (not watch): this should seed the form once from whatever printer
  // is configured when the settings screen opens, not rebuild the whole
  // controller — and discard in-progress edits — every time the session
  // changes, which also happens as a side effect of save() itself.
  final existing = ref.read(printerSessionProvider).config;
  return PrinterSetupController(ref, existing);
});

/// Static catalog providers, exposed so the settings UI doesn't import
/// core model files directly for enumeration.
final printerModelCatalogProvider = Provider<List<PrinterModel>>(
  (ref) => PrinterModel.catalog,
);
