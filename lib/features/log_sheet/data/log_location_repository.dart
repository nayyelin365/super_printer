import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/log_location.dart';

/// Firestore-backed storage for the "Unit Name / Location" list shared by
/// every log entry, across every [LogType] and every device.
class LogLocationRepository {
  LogLocationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('log_locations');

  Stream<List<LogLocation>> watchLocations() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((doc) => LogLocation.fromMap(doc.id, doc.data())).toList());
  }

  /// Writes the default location list the first time this is ever called
  /// against an empty collection — a one-time seed, never re-run once any
  /// location (default or user-added) already exists.
  Future<void> ensureSeeded() async {
    final existing = await _collection.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (final name in defaultLogLocationNames) {
      batch.set(_collection.doc(), {'name': name});
    }
    await batch.commit();
  }

  Future<LogLocation> addLocation(String name) async {
    final trimmed = name.trim();
    final doc = await _collection.add({'name': trimmed});
    return LogLocation(id: doc.id, name: trimmed);
  }
}
