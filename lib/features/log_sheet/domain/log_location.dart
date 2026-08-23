/// A selectable "Unit Name / Location" for a log entry (e.g. "Walk-in
/// Cooler") — persisted in Firestore so a location added from the entry
/// form is immediately available for every future entry, on every device.
class LogLocation {
  const LogLocation({required this.id, required this.name});

  final String id;
  final String name;

  factory LogLocation.fromMap(String id, Map<String, dynamic> data) {
    return LogLocation(id: id, name: data['name'] as String);
  }

  Map<String, dynamic> toMap() => {'name': name};
}

/// Seeded into Firestore once, the first time the location list is empty
/// — see `LogLocationRepository.ensureSeeded`.
const defaultLogLocationNames = [
  'Walk-in Cooler',
  'Poke Cold Display Line 1',
  'Poke Cold Display Line 2',
  'Cooler Under Prep Table 1',
  'Cooler Under Prep Table 2',
  'Walk-in Freezer',
];
