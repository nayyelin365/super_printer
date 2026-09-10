/// The four kitchen log sheets. Each one is a purpose-built form + history
/// view + Excel/PDF export that mirrors a real paper log the kitchen keeps
/// — unlike the earlier single generic "temperature row" model, these do
/// not share a record shape (see the four `*_record.dart` models and
/// [LogRecord]).
///
/// The guided **Sushi Rice Preparation SOP** (`/logs/sushiRice/...`,
/// `SushiRiceBatch`) is a separate feature and is unrelated to
/// [LogType.sushiRicePh], which is a plain standalone daily pH form.
enum LogType {
  sushiRicePh('Sushi Rice pH Log'),
  sushiBarTemp('Sushi Bar Temp Log'),
  cooling('Cooling Log'),
  riceHotHold('Rice Hot Holding Log');

  const LogType(this.label);

  final String label;

  /// Firestore's `logType` field value and the go_router path segment —
  /// `LogType.values.byName(id)` is the inverse.
  String get id => name;

  /// Short prefix for this log's human-readable sequential document ids
  /// (e.g. `SRPH-0823202600001`) — see `LogRecordRepository`.
  String get idPrefix => switch (this) {
        LogType.sushiRicePh => 'SRPH',
        LogType.sushiBarTemp => 'SBTL',
        LogType.cooling => 'COOL',
        LogType.riceHotHold => 'RHHL',
      };
}
