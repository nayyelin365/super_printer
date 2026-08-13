/// Zebra printer calibration/media settings.
///
/// These map to the ZPL `^MD`, `^PR`, `^PW`, `^LL`, `^PO`, `^LS`/`^LT`
/// commands sent ahead of the label graphic. Defaults are safe values for a
/// 3 x 2 inch direct-thermal label; expose these as settings later if finer
/// control is needed.
class PrinterCalibration {
  const PrinterCalibration({
    this.darkness = 15,
    this.speedInchesPerSecond = 4,
    this.orientation = PrintOrientation.normal,
    this.offsetXDots = 0,
    this.offsetYDots = 0,
  });

  /// Print darkness, 0-30 on most Zebra desktop printers.
  final int darkness;

  /// Print speed in inches/second, typically 2-6 for desktop printers.
  final int speedInchesPerSecond;

  final PrintOrientation orientation;

  final int offsetXDots;
  final int offsetYDots;

  PrinterCalibration copyWith({
    int? darkness,
    int? speedInchesPerSecond,
    PrintOrientation? orientation,
    int? offsetXDots,
    int? offsetYDots,
  }) {
    return PrinterCalibration(
      darkness: darkness ?? this.darkness,
      speedInchesPerSecond: speedInchesPerSecond ?? this.speedInchesPerSecond,
      orientation: orientation ?? this.orientation,
      offsetXDots: offsetXDots ?? this.offsetXDots,
      offsetYDots: offsetYDots ?? this.offsetYDots,
    );
  }

  Map<String, dynamic> toJson() => {
        'darkness': darkness,
        'speed': speedInchesPerSecond,
        'orientation': orientation.name,
        'offsetX': offsetXDots,
        'offsetY': offsetYDots,
      };

  factory PrinterCalibration.fromJson(Map<String, dynamic> json) {
    return PrinterCalibration(
      darkness: json['darkness'] as int? ?? 15,
      speedInchesPerSecond: json['speed'] as int? ?? 4,
      orientation: PrintOrientation.values.firstWhere(
        (o) => o.name == json['orientation'],
        orElse: () => PrintOrientation.normal,
      ),
      offsetXDots: json['offsetX'] as int? ?? 0,
      offsetYDots: json['offsetY'] as int? ?? 0,
    );
  }
}

enum PrintOrientation { normal, inverted }
