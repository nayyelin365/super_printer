/// A printer make/model entry.
///
/// Modeled as a catalog of const instances (rather than an enum) so new
/// Zebra models can be added by appending to [PrinterModel.catalog] without
/// touching any switch statements elsewhere in the app.
class PrinterModel {
  const PrinterModel(this.id, this.displayName, {this.isZebra = true});

  final String id;
  final String displayName;
  final bool isZebra;

  static const zd220 = PrinterModel('zebra_zd220', 'Zebra ZD220');
  static const zd230 = PrinterModel('zebra_zd230', 'Zebra ZD230');
  static const zd420 = PrinterModel('zebra_zd420', 'Zebra ZD420');
  static const zd421 = PrinterModel('zebra_zd421', 'Zebra ZD421');
  static const zm400 = PrinterModel('zebra_zm400', 'Zebra ZM400');
  static const otherZebra = PrinterModel('other_zebra', 'Other Zebra Printer');
  static const otherPrinter =
      PrinterModel('other_printer', 'Other Printer', isZebra: false);

  /// All known models. Append new Zebra models here.
  static const List<PrinterModel> catalog = [
    zd220,
    zd230,
    zd420,
    zd421,
    zm400,
    otherZebra,
    otherPrinter,
  ];

  static PrinterModel fromId(String id) => catalog.firstWhere(
        (m) => m.id == id,
        orElse: () => otherPrinter,
      );

  @override
  bool operator ==(Object other) => other is PrinterModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => displayName;
}
