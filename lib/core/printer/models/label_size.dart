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

  static const List<LabelSize> catalog = [threeByTwo];

  static LabelSize fromId(String id) => catalog.firstWhere(
        (s) => s.id == id,
        orElse: () => threeByTwo,
      );

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
