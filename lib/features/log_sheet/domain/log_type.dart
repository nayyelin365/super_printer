/// The six kitchen log sheets — one reusable table/form/repository backs
/// all of them (see `LogEntry`, `LogRepository`), driven by this enum
/// rather than six independent feature implementations. Every type shares
/// the same columns today; a type needing extra/different fields later can
/// branch off `LogType` without touching the others.
enum LogType {
  sushiRice('Sushi Rice Log'),
  temperature('Temperature Log'),
  cooling('Cooling Log'),
  recooling('Recooling Log'),
  coolPrep('Cool Prep Log'),
  thawing('Thawing Log');

  const LogType(this.label);

  final String label;

  /// Firestore's `logType` field value and the go_router path segment —
  /// `LogType.values.byName(id)` is the inverse.
  String get id => name;
}
