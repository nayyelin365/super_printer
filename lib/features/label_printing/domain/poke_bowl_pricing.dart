/// Fixed base price option for the Poke Bowl / Burrito template, offered as
/// a quick-select chip above the Total Amount field. Only one can be active
/// at a time — picking one sets the total outright (see
/// `LabelPrintController.selectBasePrice`).
class BasePriceOption {
  const BasePriceOption(this.label, this.amount);
  final String label;
  final double amount;
}

const basePriceOptions = [
  BasePriceOption('Chicken S', 8.00),
  BasePriceOption('Chicken R', 11.00),
  BasePriceOption('Chicken L', 13.00),
  BasePriceOption('SeaFood S', 10.00),
  BasePriceOption('SeaFood R', 13.00),
  BasePriceOption('SeaFood L', 16.50),
];

/// Fixed "extra" add-on amounts — unlike [basePriceOptions], tapping one adds
/// to the current total and can be tapped any number of times (see
/// `LabelPrintController.addExtraPrice`).
const extraPriceOptions = [3.50, 2.00, 1.75, 0.75, 0.50];
