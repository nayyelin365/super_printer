import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/printer/label_printer.dart';
import '../../../core/printer/models/label_size.dart';
import '../../../core/printer/models/printer_calibration.dart';
import '../../../core/printer/printer_exceptions.dart';
import '../../../core/printer/printer_session_controller.dart';
import '../domain/label_data.dart';
import '../domain/label_renderer.dart';

class LabelPrintState {
  LabelPrintState({
    LabelData? labelData,
    this.quantity = 1,
    this.useByDays = 3,
    this.amountText = '',
    this.isPrinting = false,
    this.printedCount = 0,
    this.printTotal = 0,
    this.resultMessage,
    this.errorMessage,
    this.formGeneration = 0,
  }) : labelData = labelData ?? LabelData.initial();

  final LabelData labelData;
  final int quantity;
  final int useByDays;
  final String amountText;

  final bool isPrinting;
  final int printedCount;
  final int printTotal;
  final String? resultMessage;
  final String? errorMessage;

  /// Bumped only by [LabelPrintController.reset]. Text fields key off this
  /// (instead of their own value) so external resets force the on-screen
  /// text to refresh, while normal typing never resets cursor/focus.
  final int formGeneration;

  LabelPrintState copyWith({
    LabelData? labelData,
    int? quantity,
    int? useByDays,
    String? amountText,
    bool? isPrinting,
    int? printedCount,
    int? printTotal,
    String? Function()? resultMessage,
    String? Function()? errorMessage,
    int? formGeneration,
  }) {
    return LabelPrintState(
      labelData: labelData ?? this.labelData,
      quantity: quantity ?? this.quantity,
      useByDays: useByDays ?? this.useByDays,
      amountText: amountText ?? this.amountText,
      isPrinting: isPrinting ?? this.isPrinting,
      printedCount: printedCount ?? this.printedCount,
      printTotal: printTotal ?? this.printTotal,
      resultMessage: resultMessage != null ? resultMessage() : this.resultMessage,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      formGeneration: formGeneration ?? this.formGeneration,
    );
  }
}

class LabelPrintController extends StateNotifier<LabelPrintState> {
  LabelPrintController(this._ref) : super(LabelPrintState());

  final Ref _ref;
  final LabelRenderer _renderer = const LabelRenderer();

  void updateProductName(String value) {
    state = state.copyWith(
      labelData: state.labelData.copyWith(productName: value),
      resultMessage: () => null,
    );
  }

  void updateNetWeight(String value) {
    final parsed = double.tryParse(value);
    state = state.copyWith(
      labelData: state.labelData.copyWith(netWeight: () => parsed),
      resultMessage: () => null,
    );
  }

  void updatePricePerLb(String value) {
    final parsed = double.tryParse(value);
    state = state.copyWith(
      labelData: state.labelData.copyWith(pricePerLb: () => parsed),
      resultMessage: () => null,
    );
  }

  void updateAmount(String value) {
    final parsed = double.tryParse(value) ?? 0;
    state = state.copyWith(
      amountText: value,
      labelData: state.labelData.copyWith(totalAmount: parsed),
      resultMessage: () => null,
    );
  }

  void toggleShowBarcode(bool value) {
    state = state.copyWith(
      labelData: state.labelData.copyWith(showBarcode: value),
      resultMessage: () => null,
    );
  }

  void updateQuantity(int value) {
    if (value < 1) return;
    state = state.copyWith(quantity: value, resultMessage: () => null);
  }

  void updateUseByDays(int days) {
    final packedAt = state.labelData.packedAt;
    state = state.copyWith(
      useByDays: days,
      labelData: state.labelData.copyWith(
        useBy: packedAt.add(Duration(days: days)),
      ),
      resultMessage: () => null,
    );
  }

  void reset() {
    state = LabelPrintState(formGeneration: state.formGeneration + 1);
  }

  /// Starts a fresh label for a food picked on the Food Selection screen —
  /// same as [reset], but pre-fills the product name. This never touches
  /// the food catalog itself, only the label being edited.
  void startNewLabel(String foodName) {
    state = LabelPrintState(
      labelData: LabelData.initial().copyWith(productName: foodName),
      formGeneration: state.formGeneration + 1,
    );
  }

  Future<void> print() async {
    final session = _ref.read(printerSessionProvider);
    final printer = _ref.read(printerSessionProvider.notifier).printer;

    if (printer == null || session.status != PrinterConnectionStatus.connected) {
      state = state.copyWith(
        errorMessage: () =>
            'Printer is not connected. Please connect a printer before printing.',
        resultMessage: () => null,
      );
      return;
    }
    if (state.quantity < 1) {
      state = state.copyWith(errorMessage: () => 'Enter a valid quantity.');
      return;
    }
    if (state.labelData.totalAmount < 0) {
      state = state.copyWith(errorMessage: () => 'Enter a valid amount.');
      return;
    }

    final config = session.config;
    final dpi = config?.dpi ?? 300;
    final labelSize = config?.labelSize ?? LabelSize.threeByTwo;
    final pixels = labelSize.pixelSize(dpi);
    final calibration = config?.calibration;

    state = state.copyWith(
      isPrinting: true,
      printedCount: 0,
      printTotal: state.quantity,
      errorMessage: () => null,
      resultMessage: () => null,
    );

    try {
      final bitmap = await _renderer.renderToGrayscale(
        data: state.labelData,
        width: pixels.width,
        height: pixels.height,
      );

      // One transmitted image, printed `quantity` times via the printer's
      // own copy count (^PQ) — avoids re-sending the bitmap per copy.
      await printer.printImage(
        bitmap,
        width: pixels.width,
        height: pixels.height,
        calibration: calibration ?? const PrinterCalibration(),
        copies: state.quantity,
      );

      state = state.copyWith(
        isPrinting: false,
        printedCount: state.quantity,
        resultMessage: () =>
            '${state.quantity} label${state.quantity == 1 ? '' : 's'} printed successfully.',
      );
    } on PrinterException catch (e) {
      state = state.copyWith(isPrinting: false, errorMessage: () => e.message);
    } catch (_) {
      state = state.copyWith(
        isPrinting: false,
        errorMessage: () => 'Printing failed. Please try again.',
      );
    }
  }
}

final labelPrintControllerProvider =
    StateNotifierProvider<LabelPrintController, LabelPrintState>(
  (ref) => LabelPrintController(ref),
);
