import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/printer_storage.dart';
import 'bluetooth_label_printer.dart';
import 'label_printer.dart';
import 'models/printer_config.dart';
import 'printer_exceptions.dart';
import 'printer_registry.dart';
import 'usb_label_printer.dart';
import 'zpl_encoder.dart';

/// The single source of truth for "which printer is active right now".
///
/// Both the printer settings screen (which sets this up) and the label
/// printing screen (which prints through it) read from the same session so
/// connection status never drifts between the two.
class PrinterSessionState {
  const PrinterSessionState({
    this.config,
    this.status = PrinterConnectionStatus.disconnected,
    this.isLoading = false,
    this.errorMessage,
  });

  final PrinterConfig? config;
  final PrinterConnectionStatus status;
  final bool isLoading;
  final String? errorMessage;

  PrinterSessionState copyWith({
    PrinterConfig? config,
    PrinterConnectionStatus? status,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return PrinterSessionState(
      config: config ?? this.config,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class PrinterSessionController extends StateNotifier<PrinterSessionState> {
  PrinterSessionController(this._storage) : super(const PrinterSessionState()) {
    _restore();
  }

  final PrinterStorage _storage;
  final ZplEncoder _encoder = const ZplEncoder();
  LabelPrinter? _printer;

  LabelPrinter? get printer => _printer;

  Future<void> _restore() async {
    state = state.copyWith(isLoading: true);
    final saved = await _storage.loadDefault();
    if (saved == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    state = state.copyWith(config: saved, isLoading: false);
    await reconnect();
  }

  /// Attempts to reconnect to the saved printer with a bounded timeout.
  /// Does not retry indefinitely — the user can trigger this again manually.
  Future<void> reconnect() async {
    final config = state.config;
    if (config == null) return;

    state = state.copyWith(
      status: PrinterConnectionStatus.connecting,
      errorMessage: () => null,
    );

    _printer?.dispose();
    _printer = PrinterRegistry.create(config.connectionType);

    try {
      await _printer!
          .connect(config.toPrinterDevice())
          .timeout(const Duration(seconds: 10));
      state = state.copyWith(status: PrinterConnectionStatus.connected);
    } catch (e) {
      state = state.copyWith(
        status: PrinterConnectionStatus.disconnected,
        errorMessage: () => _messageFor(e),
      );
    }
  }

  /// Hands off an already-connected printer transport (from the settings
  /// discovery flow) and persists its configuration as the default.
  Future<void> adopt(PrinterConfig config, LabelPrinter connectedPrinter) async {
    _printer?.dispose();
    _printer = connectedPrinter;
    await _storage.save(config);
    state = state.copyWith(
      config: config,
      status: PrinterConnectionStatus.connected,
      errorMessage: () => null,
    );
  }

  Future<void> disconnect() async {
    await _printer?.disconnect();
    state = state.copyWith(status: PrinterConnectionStatus.disconnected);
  }

  Future<bool> isConnected() async => await _printer?.isConnected() ?? false;

  Future<String> testPrint() async {
    final config = state.config;
    final printer = _printer;
    if (config == null || printer == null || !(await isConnected())) {
      throw const PrinterException(
        PrinterErrorCode.notConnected,
        'Printer is not connected. Please connect a printer before printing.',
      );
    }

    final zpl = _encoder.buildTestLabelZpl(
      printerName: config.name,
      labelSize: config.labelSize.displayName,
      dpi: config.dpi,
      connectionType: config.connectionType.label,
    );

    if (printer is BluetoothLabelPrinter) {
      await printer.printRawZpl(zpl);
    } else if (printer is UsbLabelPrinter) {
      await printer.printRawZpl(zpl);
    }
    return '1 test label printed successfully.';
  }

  String _messageFor(Object e) {
    if (e is PrinterException) return e.message;
    return 'Could not connect to the printer.';
  }

  @override
  void dispose() {
    _printer?.dispose();
    super.dispose();
  }
}

final printerStorageProvider = Provider<PrinterStorage>((ref) => PrinterStorage());

final printerSessionProvider =
    StateNotifierProvider<PrinterSessionController, PrinterSessionState>(
  (ref) => PrinterSessionController(ref.watch(printerStorageProvider)),
);
