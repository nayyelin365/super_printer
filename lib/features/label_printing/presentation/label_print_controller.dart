import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/printer/label_printer.dart';
import '../../../core/printer/models/label_size.dart';
import '../../../core/printer/models/printer_calibration.dart';
import '../../../core/printer/printer_exceptions.dart';
import '../../../core/printer/printer_session_controller.dart';
import '../domain/food_rotation_label_data.dart';
import '../domain/label_data.dart';
import '../domain/label_template.dart';
import '../domain/label_template_renderer.dart';

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
  }) : labelData = labelData ?? PokeBowlLabelData.initial();

  final LabelData labelData;
  final int quantity;
  final int useByDays;
  final String amountText;

  final bool isPrinting;
  final int printedCount;
  final int printTotal;
  final String? resultMessage;
  final String? errorMessage;

  /// Bumped only by [LabelPrintController.reset]/[LabelPrintController.startNewLabel].
  /// Text fields key off this (instead of their own value) so external
  /// resets force the on-screen text to refresh, while normal typing never
  /// resets cursor/focus.
  final int formGeneration;

  /// Which template [labelData] belongs to — derived from the data itself
  /// so the two can never drift out of sync.
  LabelTemplateType get template => labelData.templateType;

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

  // ---- Poke Bowl / Burrito fields --------------------------------------

  void updateProductName(String value) {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    state = state.copyWith(
      labelData: data.copyWith(productName: value),
      resultMessage: () => null,
    );
  }

  void updateNetWeight(String value) {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    final parsed = double.tryParse(value);
    state = state.copyWith(
      labelData: data.copyWith(netWeight: () => parsed),
      resultMessage: () => null,
    );
  }

  void updatePricePerLb(String value) {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    final parsed = double.tryParse(value);
    state = state.copyWith(
      labelData: data.copyWith(pricePerLb: () => parsed),
      resultMessage: () => null,
    );
  }

  void updateAmount(String value) {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    final parsed = double.tryParse(value) ?? 0;
    state = state.copyWith(
      amountText: value,
      labelData: data.copyWith(totalAmount: parsed),
      resultMessage: () => null,
    );
  }

  void toggleShowBarcode(bool value) {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    state = state.copyWith(
      labelData: data.copyWith(showBarcode: value),
      resultMessage: () => null,
    );
  }

  // ---- Food Rotation fields ---------------------------------------------

  void updateFoodName(String value) {
    final data = state.labelData;
    if (data is! FoodRotationLabelData) return;
    state = state.copyWith(
      labelData: data.copyWith(foodName: value),
      resultMessage: () => null,
    );
  }

  void updatePrepDateTime(DateTime value) {
    final data = state.labelData;
    if (data is! FoodRotationLabelData) return;
    state = state.copyWith(
      labelData: data.copyWith(
        prepDateTime: value,
        useBy: value.add(Duration(days: state.useByDays)),
      ),
      resultMessage: () => null,
    );
  }

  void updateEmployee(String value) {
    final data = state.labelData;
    if (data is! FoodRotationLabelData) return;
    state = state.copyWith(
      labelData: data.copyWith(employee: value),
      resultMessage: () => null,
    );
  }

  // ---- Shared fields ------------------------------------------------------

  void updateQuantity(int value) {
    if (value < 1) return;
    state = state.copyWith(quantity: value, resultMessage: () => null);
  }

  /// Days from the template's "start" date (packed date for Poke Bowl, prep
  /// date/time for Food Rotation) used to compute Use By.
  void updateUseByDays(int days) {
    final data = state.labelData;
    final LabelData updated = switch (data) {
      PokeBowlLabelData d => d.copyWith(useBy: d.packedAt.add(Duration(days: days))),
      FoodRotationLabelData d => d.copyWith(useBy: d.prepDateTime.add(Duration(days: days))),
      _ => data,
    };
    state = state.copyWith(
      useByDays: days,
      labelData: updated,
      resultMessage: () => null,
    );
  }

  void reset() {
    state = LabelPrintState(
      labelData: _freshData(state.template, foodName: null),
      formGeneration: state.formGeneration + 1,
    );
  }

  /// Starts a fresh label for the given [templateType] — same as [reset],
  /// but for switching templates (or pre-filling a food name picked on the
  /// Food Selection screen). Never touches the food catalog or any other
  /// template's data.
  void startNewLabel(LabelTemplateType templateType, {String? foodName}) {
    state = LabelPrintState(
      labelData: _freshData(templateType, foodName: foodName),
      formGeneration: state.formGeneration + 1,
    );
  }

  LabelData _freshData(LabelTemplateType type, {String? foodName}) {
    return switch (type) {
      LabelTemplateType.pokeBowlBurrito => foodName == null
          ? PokeBowlLabelData.initial()
          : PokeBowlLabelData.initial().copyWith(productName: foodName),
      LabelTemplateType.foodRotation => FoodRotationLabelData.initial().copyWith(
          foodName: foodName ?? '',
        ),
    };
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
    final labelData = state.labelData;
    if (labelData is PokeBowlLabelData && labelData.totalAmount < 0) {
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
      final renderer = LabelTemplateRenderers.forData(state.labelData);
      final bitmap = await renderer.renderToGrayscale(
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
