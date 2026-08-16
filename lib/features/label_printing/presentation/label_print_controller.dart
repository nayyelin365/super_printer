import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/printer/label_printer.dart';
import '../../../core/printer/models/label_size.dart';
import '../../../core/printer/models/printer_calibration.dart';
import '../../../core/printer/printer_exceptions.dart';
import '../../../core/printer/printer_session_controller.dart';
import '../../food_selection/domain/food_catalog.dart';
import '../../food_selection/presentation/food_selection_controller.dart';
import '../domain/custom_label_data.dart';
import '../domain/food_rotation_label_data.dart';
import '../domain/label_component.dart';
import '../domain/label_data.dart';
import '../domain/label_template.dart';
import '../domain/label_template_renderer.dart';

class LabelPrintState {
  LabelPrintState({
    LabelData? labelData,
    this.quantity = 1,
    this.useByAmount = 24,
    this.amountText = '',
    this.amountGeneration = 0,
    this.isPrinting = false,
    this.printedCount = 0,
    this.printTotal = 0,
    this.resultMessage,
    this.errorMessage,
    this.formGeneration = 0,
  }) : labelData = labelData ?? PokeBowlLabelData.initial();

  final LabelData labelData;
  final int quantity;

  /// Number of hours from the template's "start" date/time the user typed
  /// for Use By — see [LabelPrintController.useByDuration].
  final int useByAmount;
  final String amountText;

  /// Bumped whenever [amountText] is set programmatically (base/extra price
  /// buttons, clear) rather than typed — the Total Amount field keys off
  /// this (see [formGeneration]) so those updates refresh the on-screen
  /// text without disturbing cursor/focus while the seller is typing.
  final int amountGeneration;

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

  /// The full [LabelTemplate] behind [labelData]: for custom templates
  /// that's carried on the data itself; for built-ins it's looked up from
  /// the fixed catalog.
  LabelTemplate get fullTemplate {
    final data = labelData;
    if (data is CustomLabelData) return data.template;
    return LabelTemplateCatalog.builtIns.firstWhere((t) => t.type == data.templateType);
  }

  LabelPrintState copyWith({
    LabelData? labelData,
    int? quantity,
    int? useByAmount,
    String? amountText,
    int? amountGeneration,
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
      useByAmount: useByAmount ?? this.useByAmount,
      amountText: amountText ?? this.amountText,
      amountGeneration: amountGeneration ?? this.amountGeneration,
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

  /// Sets Total Amount to [amount] outright — for the base-price quick
  /// picks, of which only one applies at a time.
  void selectBasePrice(double amount) {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    state = state.copyWith(
      amountText: _formatAmount(amount),
      amountGeneration: state.amountGeneration + 1,
      labelData: data.copyWith(totalAmount: amount),
      resultMessage: () => null,
    );
  }

  /// Adds [amount] on top of the current Total Amount — for the extra-price
  /// quick picks, which can be tapped any number of times.
  void addExtraPrice(double amount) {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    final total = data.totalAmount + amount;
    state = state.copyWith(
      amountText: _formatAmount(total),
      amountGeneration: state.amountGeneration + 1,
      labelData: data.copyWith(totalAmount: total),
      resultMessage: () => null,
    );
  }

  void clearAmount() {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    state = state.copyWith(
      amountText: '',
      amountGeneration: state.amountGeneration + 1,
      labelData: data.copyWith(totalAmount: 0),
      resultMessage: () => null,
    );
  }

  static String _formatAmount(double amount) {
    return amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
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
        useBy: value.add(useByDuration(state.useByAmount)),
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

  void updatePh(String value) {
    final data = state.labelData;
    if (data is! FoodRotationLabelData) return;
    state = state.copyWith(
      labelData: data.copyWith(ph: value),
      resultMessage: () => null,
    );
  }

  void toggleShowPh(bool value) {
    final data = state.labelData;
    if (data is! FoodRotationLabelData) return;
    state = state.copyWith(
      labelData: data.copyWith(showPh: value),
      resultMessage: () => null,
    );
  }

  // ---- Custom template fields --------------------------------------------

  /// Updates a dynamic field's runtime value for a custom template — e.g.
  /// a `text`/`barcode` component's fieldKey. Date/time-bound fields go
  /// through [updateCustomPackedAt]/[updateUseByAmount] instead, so the Use
  /// By input stays consistent with the built-in templates.
  void updateCustomFieldValue(String fieldKey, String value) {
    final data = state.labelData;
    if (data is! CustomLabelData) return;
    state = state.copyWith(
      labelData: data.withFieldValue(fieldKey, value),
      resultMessage: () => null,
    );
  }

  void updateCustomPackedAt(DateTime value) {
    final data = state.labelData;
    if (data is! CustomLabelData) return;
    final hasUseBy = data.useBy != null;
    state = state.copyWith(
      labelData: hasUseBy
          ? data.copyWith(
              packedAt: value,
              useByAt: () => value.add(useByDuration(state.useByAmount)),
            )
          : data.copyWith(packedAt: value),
      resultMessage: () => null,
    );
  }

  // ---- Shared fields ------------------------------------------------------

  void updateQuantity(int value) {
    if (value < 1) return;
    state = state.copyWith(quantity: value, resultMessage: () => null);
  }

  /// The typed number is always hours from the template's "start" date —
  /// e.g. 12 -> 12 hours, 48 -> 48 hours, 124 -> 124 hours.
  static Duration useByDuration(int amount) => Duration(hours: amount);

  /// Offset from the template's "start" date (packed date for Poke Bowl,
  /// prep date/time for Food Rotation, packed time for custom templates)
  /// used to compute Use By — see [useByDuration].
  void updateUseByAmount(int amount) {
    if (amount < 0) return;
    final duration = useByDuration(amount);
    final data = state.labelData;
    final LabelData updated = switch (data) {
      PokeBowlLabelData d => d.copyWith(useBy: d.packedAt.add(duration)),
      FoodRotationLabelData d => d.copyWith(useBy: d.prepDateTime.add(duration)),
      CustomLabelData d when d.useBy != null =>
        d.copyWith(useByAt: () => d.packedAt.add(duration)),
      _ => data,
    };
    state = state.copyWith(
      useByAmount: amount,
      labelData: updated,
      resultMessage: () => null,
    );
  }

  void reset() {
    state = LabelPrintState(
      labelData: _freshData(state.fullTemplate, foodName: null),
      formGeneration: state.formGeneration + 1,
    );
  }

  /// Starts a fresh label for [template] — same as [reset], but for
  /// switching templates (or pre-filling a food name picked on the Food
  /// Selection screen). Never touches the food catalog, the template
  /// catalog, or any other template's data.
  ///
  /// [food] is the catalog entry [foodName] came from — when it carries
  /// saved Use By hours, employee, and pH (see [saveCurrentFoodSettings]),
  /// a Food Rotation label pre-fills those instead of the bare defaults.
  void startNewLabel(LabelTemplate template, {String? foodName, FoodModel? food}) {
    state = LabelPrintState(
      labelData: _freshData(template, foodName: foodName, food: food),
      useByAmount: food?.useByHours ?? 24,
      formGeneration: state.formGeneration + 1,
    );
  }

  LabelData _freshData(LabelTemplate template, {String? foodName, FoodModel? food}) {
    return switch (template.type) {
      LabelTemplateType.pokeBowlBurrito => foodName == null
          ? PokeBowlLabelData.initial()
          : PokeBowlLabelData.initial().copyWith(productName: foodName),
      LabelTemplateType.foodRotation => () {
          final now = DateTime.now();
          final ph = food?.ph ?? '';
          return FoodRotationLabelData(
            foodName: foodName ?? '',
            prepDateTime: now,
            useBy: now.add(useByDuration(food?.useByHours ?? 24)),
            employee: food?.employee ?? '',
            ph: ph,
            showPh: ph.trim().isNotEmpty,
          );
        }(),
      LabelTemplateType.custom => () {
          final base = CustomLabelData.initial(template);
          return foodName == null
              ? base
              : base.withFieldValue(LabelFieldKey.foodName, foodName);
        }(),
    };
  }

  /// Saves the current Use By hours, employee, and pH back onto the food
  /// catalog entry for this label's food name, so selecting that food
  /// again later pre-fills them instead of the bare defaults. A no-op if
  /// this isn't a Food Rotation label or the food name is blank.
  void saveCurrentFoodSettings() {
    final data = state.labelData;
    if (data is! FoodRotationLabelData) return;
    final name = data.foodName.trim();
    if (name.isEmpty) return;

    _ref.read(foodCatalogProvider.notifier).saveFoodSettings(
          name,
          useByHours: state.useByAmount,
          employee: data.employee.trim().isEmpty ? null : data.employee.trim(),
          ph: data.showPh && data.ph.trim().isNotEmpty ? data.ph.trim() : null,
        );

    state = state.copyWith(resultMessage: () => 'Saved settings for "$name".');
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
