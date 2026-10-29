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
import '../data/sushi_label_preset_repository.dart';
import '../domain/poke_bowl_pricing.dart';
import '../domain/sushi_barcode.dart';
import '../domain/sushi_template_label_data.dart';
import 'print_count_controller.dart';
import 'sushi_preset_controller.dart';

/// How the Use By date/time is decided.
///
/// - [hours]: user types a number of hours; Use By is that offset from the
///   template's "start" (packed date for Poke Bowl, prep date/time for
///   Food Rotation, packed time for custom templates). This is the default.
/// - [dateTime]: user picks an absolute Use By date and time directly —
///   handy for long shelf lives where counting hours is awkward.
enum UseByMode { hours, dateTime }

class LabelPrintState {
  LabelPrintState({
    LabelData? labelData,
    this.quantity = 1,
    this.useByMode = UseByMode.hours,
    this.useByAmount = 24,
    this.amountText = '',
    this.amountGeneration = 0,
    this.isPrinting = false,
    this.printedCount = 0,
    this.printTotal = 0,
    this.resultMessage,
    this.errorMessage,
    this.formGeneration = 0,
    this.activeSushiPresetId,
    this.activeSushiPresetName,
  }) : labelData = labelData ?? PokeBowlLabelData.initial();

  final LabelData labelData;
  final int quantity;

  /// Whether Use By is computed from [useByAmount] hours or set to an
  /// absolute date/time the user picked — see [UseByMode].
  final UseByMode useByMode;

  /// Number of hours from the template's "start" date/time the user typed
  /// for Use By — see [LabelPrintController.useByDuration]. Only meaningful
  /// while [useByMode] is [UseByMode.hours].
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

  /// Sushi template only: the saved preset the current fields were loaded
  /// from/last saved to, if any — null means an unsaved/new label. Drives
  /// whether "Save" in the fields editor updates that preset in place or
  /// needs a name to create a new one.
  final String? activeSushiPresetId;
  final String? activeSushiPresetName;

  /// Which template [labelData] belongs to — derived from the data itself
  /// so the two can never drift out of sync.
  LabelTemplateType get template => labelData.templateType;

  /// The physical label size this template always prints at — Sushi is
  /// always 3 x 6 in, every other built-in/custom template is 3 x 2 in.
  /// Drives both the printer picker (which saved printers are even
  /// offered) and the actual print bitmap size in [LabelPrintController.print].
  LabelSize get requiredLabelSize =>
      template == LabelTemplateType.sushiTemplate ? LabelSize.threeBySix : LabelSize.threeByTwo;

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
    UseByMode? useByMode,
    int? useByAmount,
    String? amountText,
    int? amountGeneration,
    bool? isPrinting,
    int? printedCount,
    int? printTotal,
    String? Function()? resultMessage,
    String? Function()? errorMessage,
    int? formGeneration,
    String? Function()? activeSushiPresetId,
    String? Function()? activeSushiPresetName,
  }) {
    return LabelPrintState(
      labelData: labelData ?? this.labelData,
      quantity: quantity ?? this.quantity,
      useByMode: useByMode ?? this.useByMode,
      useByAmount: useByAmount ?? this.useByAmount,
      amountText: amountText ?? this.amountText,
      amountGeneration: amountGeneration ?? this.amountGeneration,
      isPrinting: isPrinting ?? this.isPrinting,
      printedCount: printedCount ?? this.printedCount,
      printTotal: printTotal ?? this.printTotal,
      resultMessage: resultMessage != null ? resultMessage() : this.resultMessage,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      formGeneration: formGeneration ?? this.formGeneration,
      activeSushiPresetId:
          activeSushiPresetId != null ? activeSushiPresetId() : this.activeSushiPresetId,
      activeSushiPresetName:
          activeSushiPresetName != null ? activeSushiPresetName() : this.activeSushiPresetName,
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

  void updateAmount(String value) {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    final parsed = double.tryParse(value) ?? 0;
    state = state.copyWith(
      amountText: value,
      // Typing over the total by hand means the itemized base/extra
      // selections (if any) no longer necessarily add up to it, so the
      // label's price list should stop showing them.
      labelData: data.copyWith(
        basePriceLabel: () => null,
        basePriceAmount: () => null,
        extraLines: const [],
        totalAmount: parsed,
      ),
      resultMessage: () => null,
    );
  }

  /// Sets the base price to [option] — of which only one applies at a
  /// time — and recomputes Total Amount from it plus any extras already
  /// added.
  void selectBasePrice(BasePriceOption option) {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    final total = option.amount + _sumOf(data.extraLines);
    state = state.copyWith(
      amountText: _formatAmount(total),
      amountGeneration: state.amountGeneration + 1,
      labelData: data.copyWith(
        basePriceLabel: () => option.label,
        basePriceAmount: () => option.amount,
        totalAmount: total,
      ),
      resultMessage: () => null,
    );
  }

  /// Appends [option] to the extras list — unlike [selectBasePrice], this
  /// can be tapped any number of times, each adding another line.
  void addExtraPrice(ExtraPriceOption option) {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    final extraLines = [...data.extraLines, PokeBowlPriceLine(option.label, option.amount)];
    final total = (data.basePriceAmount ?? 0) + _sumOf(extraLines);
    state = state.copyWith(
      amountText: _formatAmount(total),
      amountGeneration: state.amountGeneration + 1,
      labelData: data.copyWith(extraLines: extraLines, totalAmount: total),
      resultMessage: () => null,
    );
  }

  void clearAmount() {
    final data = state.labelData;
    if (data is! PokeBowlLabelData) return;
    state = state.copyWith(
      amountText: '',
      amountGeneration: state.amountGeneration + 1,
      labelData: data.copyWith(
        basePriceLabel: () => null,
        basePriceAmount: () => null,
        extraLines: const [],
        totalAmount: 0,
      ),
      resultMessage: () => null,
    );
  }

  static double _sumOf(List<PokeBowlPriceLine> lines) =>
      lines.fold(0.0, (sum, line) => sum + line.amount);

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

  // ---- Sushi Template fields ---------------------------------------------

  void updateSushiProductTitle(String value) => _updateSushi((d) => d.copyWith(productTitle: value));

  void updateSushiFullyCookedText(String value) =>
      _updateSushi((d) => d.copyWith(fullyCookedText: value));

  void updateSushiNetWeightText(String value) =>
      _updateSushi((d) => d.copyWith(netWeightText: value));

  void updateSushiBestIfUseByLabel(String value) =>
      _updateSushi((d) => d.copyWith(bestIfUseByLabel: value));

  void updateSushiBestIfUseByAt(DateTime value) =>
      _updateSushi((d) => d.copyWith(bestIfUseByAt: value));

  /// Sets Sell Through to [days] whole days from today's date (midnight —
  /// no time component), e.g. typing `2` on Oct 22 sets Oct 24. Negative
  /// input is ignored rather than producing a past date.
  void updateSushiBestIfUseByDays(int days) {
    if (days < 0) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _updateSushi((d) => d.copyWith(bestIfUseByAt: today.add(Duration(days: days))));
  }

  void updateSushiProcessedOnLabel(String value) =>
      _updateSushi((d) => d.copyWith(processedOnLabel: value));

  void updateSushiProcessedOnAt(DateTime value) =>
      _updateSushi((d) => d.copyWith(processedOnAt: value));

  void updateSushiPrice(double value) => _updateSushi((d) => d.copyWith(price: value));

  void updateSushiRollDescription(String value) =>
      _updateSushi((d) => d.copyWith(rollDescription: value));

  void updateSushiTopDescription(String value) =>
      _updateSushi((d) => d.copyWith(topDescription: value));

  void updateSushiIngredientsText(String value) =>
      _updateSushi((d) => d.copyWith(ingredientsText: value));

  void updateSushiBarcodeType(SushiBarcodeType value) =>
      _updateSushi((d) => d.copyWith(barcodeType: value));

  void updateSushiBarcodeValue(String value) =>
      _updateSushi((d) => d.copyWith(barcodeValue: value));

  void _updateSushi(SushiTemplateLabelData Function(SushiTemplateLabelData data) update) {
    final data = state.labelData;
    if (data is! SushiTemplateLabelData) return;
    state = state.copyWith(labelData: update(data), resultMessage: () => null);
  }

  /// Starts a fresh Sushi Template Label — from [preset] if given (every
  /// text/number/barcode field copied, but Best If Use By / Processed On
  /// always reset to "now" rather than carrying over a stale saved
  /// timestamp), or blank defaults otherwise. Always starts unbound from
  /// any preset id/name — [bindSushiPreset] records that separately, once
  /// the fields editor actually saves.
  void startSushiLabel({SushiLabelPreset? preset}) {
    state = LabelPrintState(
      labelData:
          preset == null ? SushiTemplateLabelData.initial() : sushiLabelDataFromPreset(preset),
      formGeneration: state.formGeneration + 1,
      activeSushiPresetId: preset?.id,
      activeSushiPresetName: preset?.name,
    );
  }

  /// Records which saved preset the current Sushi fields are now bound to
  /// (or clears the binding with a null [id]) — called after the fields
  /// editor creates/renames/copies a preset, so a later "Save" updates the
  /// right document instead of creating a duplicate.
  void bindSushiPreset({String? id, String? name}) {
    state = state.copyWith(
      activeSushiPresetId: () => id,
      activeSushiPresetName: () => name,
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

  /// The template's "start" date/time that hours-mode Use By counts from.
  static DateTime? _useByStart(LabelData data) => switch (data) {
        PokeBowlLabelData d => d.packedAt,
        FoodRotationLabelData d => d.prepDateTime,
        CustomLabelData d when d.useBy != null => d.packedAt,
        _ => null,
      };

  /// Writes an absolute Use By [value] onto whichever label type is active.
  static LabelData _withUseBy(LabelData data, DateTime value) => switch (data) {
        PokeBowlLabelData d => d.copyWith(useBy: value),
        FoodRotationLabelData d => d.copyWith(useBy: value),
        CustomLabelData d when d.useBy != null =>
          d.copyWith(useByAt: () => value),
        _ => data,
      };

  /// Switches between typing hours and picking an absolute Use By date/time.
  /// Going back to hours recomputes Use By from the current [useByAmount].
  void setUseByMode(UseByMode mode) {
    if (mode == state.useByMode) return;
    final data = state.labelData;
    if (data.useBy == null) return;
    LabelData updated = data;
    if (mode == UseByMode.hours) {
      final start = _useByStart(data);
      if (start != null) {
        updated = _withUseBy(data, start.add(useByDuration(state.useByAmount)));
      }
    }
    state = state.copyWith(
      useByMode: mode,
      labelData: updated,
      resultMessage: () => null,
    );
  }

  /// Sets Use By to an absolute date/time the user picked (dateTime mode).
  void updateUseByDateTime(DateTime value) {
    final data = state.labelData;
    if (data.useBy == null) return;
    state = state.copyWith(
      labelData: _withUseBy(data, value),
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
    final mode = UseByMode.values.asNameMap()[food?.useByMode] ?? UseByMode.hours;
    var labelData = _freshData(template, foodName: foodName, food: food);
    // A food saved in Date & Time mode reopens showing that exact saved
    // date/time, not an hours-based recalculation.
    if (mode == UseByMode.dateTime && food?.useByAt != null && labelData is FoodRotationLabelData) {
      labelData = labelData.copyWith(useBy: food!.useByAt);
    }
    state = LabelPrintState(
      labelData: labelData,
      useByAmount: food?.useByHours ?? 48,
      useByMode: mode,
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
      LabelTemplateType.sushiTemplate => SushiTemplateLabelData.initial(),
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
          useByMode: state.useByMode.name,
          // In Date & Time mode the exact picked date/time is saved too
          // (hours alone would reopen as an hours-based recalculation).
          useByAt: state.useByMode == UseByMode.dateTime ? data.useBy : null,
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
    // Always the template's own required size (the printer picker only
    // ever offers saved printers configured for that size), not whatever
    // the connected printer happens to report — keeps print() correct even
    // if a printer's own labelSizeId were ever out of sync.
    final pixels = state.requiredLabelSize.pixelSize(dpi);
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

      // The "labels printed today" badges are per-template (Poke Bowl and
      // Sushi Template Label each keep their own running total) — don't
      // count prints of any other template toward either one.
      if (state.labelData is PokeBowlLabelData) {
        await _ref.read(printCountProvider.notifier).increment(state.quantity);
      } else if (state.labelData is SushiTemplateLabelData) {
        await _ref.read(sushiPrintCountProvider.notifier).increment(state.quantity);
      }

      // Total Amount (base price + extras) is specific to this one sale —
      // clear it after a successful print so the next label doesn't start
      // pre-filled with the last customer's total.
      final printedData = state.labelData;
      final clearedData = printedData is PokeBowlLabelData
          ? printedData.copyWith(
              basePriceLabel: () => null,
              basePriceAmount: () => null,
              extraLines: const [],
              totalAmount: 0,
            )
          : printedData;

      state = state.copyWith(
        labelData: clearedData,
        amountText: printedData is PokeBowlLabelData ? '' : state.amountText,
        amountGeneration:
            printedData is PokeBowlLabelData ? state.amountGeneration + 1 : state.amountGeneration,
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
