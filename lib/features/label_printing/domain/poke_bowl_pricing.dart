import 'package:flutter/material.dart';

const _seafoodColor = Color(0xFF3B5BDB);
const _chickenColor = Color(0xFFE03131);
const _tofuVegeColor = Color(0xFF2F9E44);
const _extraColor = Color(0xFFF08C00);

/// Fixed base price option for the Poke Bowl / Burrito template, offered as
/// a quick-select tile above the Total Amount field. Only one can be active
/// at a time — picking one sets the total outright (see
/// `LabelPrintController.selectBasePrice`).
///
/// [id] is stable identity for editing/persistence (see
/// `PokeBowlPricingController`) — [label] and [amount] can change, [id]
/// never does.
class BasePriceOption {
  const BasePriceOption(this.id, this.label, this.amount, this.color);
  final String id;
  final String label;
  final double amount;
  final Color color;

  BasePriceOption copyWith({String? label, double? amount}) {
    return BasePriceOption(id, label ?? this.label, amount ?? this.amount, color);
  }
}

/// Ordered so the UI can lay these out as a 3-column grid — protein
/// (column) × size (row) — matching how sellers read a physical price
/// board: Large/Regular/Small within each protein.
const defaultBasePriceOptions = [
  BasePriceOption('seafood_large', 'Seafood Large', 16.50, _seafoodColor),
  BasePriceOption('chicken_large', 'Chicken Large', 13.00, _chickenColor),
  BasePriceOption('tofu_vege_large', 'Tofu / Vege Large', 13.00, _tofuVegeColor),
  BasePriceOption('seafood_regular', 'Seafood Regular', 13.00, _seafoodColor),
  BasePriceOption('chicken_regular', 'Chicken Regular', 11.00, _chickenColor),
  BasePriceOption('tofu_vege_regular', 'Tofu / Vege Regular', 11.00, _tofuVegeColor),
  BasePriceOption('seafood_small', 'Seafood Small', 10.00, _seafoodColor),
  BasePriceOption('chicken_small', 'Chicken Small', 8.00, _chickenColor),
  BasePriceOption('tofu_vege_small', 'Tofu / Vege Small', 8.00, _tofuVegeColor),
];

/// Fixed "extra" add-on — unlike [defaultBasePriceOptions], tapping one adds
/// to the current total and can be tapped any number of times (see
/// `LabelPrintController.addExtraPrice`).
class ExtraPriceOption {
  const ExtraPriceOption(this.id, this.label, this.amount, this.color);
  final String id;
  final String label;
  final double amount;
  final Color color;

  ExtraPriceOption copyWith({String? label, double? amount}) {
    return ExtraPriceOption(id, label ?? this.label, amount ?? this.amount, color);
  }
}

const defaultExtraPriceOptions = [
  ExtraPriceOption('extra_seafood', 'Extra Seafood', 3.50, _seafoodColor),
  ExtraPriceOption('extra_chicken', 'Extra Chicken', 2.00, _chickenColor),
  ExtraPriceOption('extra_tofu_vege', 'Extra Tofu / Vege', 2.00, _tofuVegeColor),
  ExtraPriceOption('premium_topping', 'Premium Topping', 1.75, _extraColor),
  ExtraPriceOption('extra_side', 'Extra Side', 0.75, _extraColor),
  ExtraPriceOption('extra_sauce', 'Extra Sauce', 0.75, _extraColor),
  ExtraPriceOption('extra_crunch', 'Extra Crunch', 0.75, _extraColor),
  ExtraPriceOption('soy_sheet', 'Soy Sheet', 1.00, _extraColor),
];

/// One line of the itemized price list a Poke Bowl / Burrito label prints
/// (the selected base price, then each added extra, in order) — see
/// `PokeBowlLabelData.priceLines` and `PokeBowlLabelRenderer`.
class PokeBowlPriceLine {
  const PokeBowlPriceLine(this.label, this.amount);
  final String label;
  final double amount;
}
