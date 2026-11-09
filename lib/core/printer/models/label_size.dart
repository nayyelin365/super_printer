/// A supported physical label size, in inches.
///
/// Modeled as a catalog of const instances so additional sizes can be added
/// without touching switch statements elsewhere.
class LabelSize {
  const LabelSize(this.id, this.displayName, this.widthInches, this.heightInches);

  final String id;
  final String displayName;
  final double widthInches;
  final double heightInches;

  static const threeByTwo = LabelSize('3x2', '3 × 2 inch', 3.0, 2.0);
  static const threeBySix = LabelSize('3x6', '3 × 6 inch', 3.0, 6.0);

  /// Generic "pick a custom size" catalog entry — selecting it in Printer
  /// Settings is what reveals the width/height fields that turn it into a
  /// concrete [custom] id (`'custom:WxH'`) via [setCustomLabelSize]-style
  /// flows. On its own (no dimensions typed yet) it won't match any real
  /// template's [LabelPrintState.requiredLabelSize], which always carries
  /// real dimensions — see [custom].
  static const custom = LabelSize('custom', 'Custom (set per template)', 3.0, 2.0);

  static const List<LabelSize> catalog = [threeByTwo, threeBySix, custom];

  /// A concrete custom size, e.g. for a printer dedicated to 2 x 2 in
  /// custom templates specifically (distinct from one dedicated to 4 x 6
  /// in custom templates) — unlike the flat [custom] placeholder, this
  /// encodes the actual dimensions into the id (`'custom:WxH'`) so two
  /// different custom sizes are never treated as the same printer bucket.
  /// `LabelPrintState.requiredLabelSize` builds one of these from a custom
  /// template's own size, and Printer Settings' custom width/height fields
  /// build one the same way when saving a dedicated printer.
  static LabelSize sized(double widthInches, double heightInches) {
    final w = widthInches.toStringAsFixed(1);
    final h = heightInches.toStringAsFixed(1);
    return LabelSize('custom:${w}x$h', 'Custom ($w × $h in)', widthInches, heightInches);
  }

  static final RegExp _customIdPattern = RegExp(r'^custom:([0-9.]+)x([0-9.]+)$');

  static LabelSize fromId(String id) {
    final match = _customIdPattern.firstMatch(id);
    if (match != null) {
      final w = double.tryParse(match.group(1)!) ?? threeByTwo.widthInches;
      final h = double.tryParse(match.group(2)!) ?? threeByTwo.heightInches;
      return sized(w, h);
    }
    return catalog.firstWhere(
      (s) => s.id == id,
      orElse: () => threeByTwo,
    );
  }

  /// Pixel dimensions of the printable canvas at the given [dpi].
  ({int width, int height}) pixelSize(int dpi) => (
        width: (widthInches * dpi).round(),
        height: (heightInches * dpi).round(),
      );

  @override
  bool operator ==(Object other) => other is LabelSize && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => displayName;
}
