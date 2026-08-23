import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/log_entry.dart';
import '../domain/log_type.dart';

/// Firestore-backed storage for log entries — one collection shared by all
/// six [LogType]s (filtered by the `logType` field). See the class doc on
/// [LogEntry] for why food/location are snapshotted rather than
/// referenced live.
///
/// Queries only filter by `logType` (a single-field equality, which
/// Firestore indexes automatically) and sort client-side by date/time —
/// deliberately avoiding a `where(logType) + orderBy(date)` composite
/// query, which would need a manually-created Firestore index before it
/// would work.
class LogRepository {
  LogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('logs');

  /// Live updates for every entry of [logType], newest first.
  Stream<List<LogEntry>> watchEntries(LogType logType) {
    return _collection.where('logType', isEqualTo: logType.id).snapshots().map((snapshot) {
      final entries = snapshot.docs.map((doc) => LogEntry.fromMap(doc.id, doc.data())).toList();
      entries.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return entries;
    });
  }

  Future<void> addEntry(LogEntry entry) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final docId = await _nextLogId(entry.date);
    await _collection.doc(docId).set({
      ...entry.toMap(),
      'createdAtMillis': now,
      'updatedAtMillis': now,
    });
  }

  /// Builds a human-readable, sequential document id like `Logs-082320260001`
  /// (`Logs-` + `MMDDYYYY` + a 4-digit counter for that date) instead of
  /// Firestore's default random id. The counter lives in its own
  /// `log_counters/{MMDDYYYY}` document and is incremented inside a
  /// transaction so concurrent saves (even from different devices) never
  /// collide on the same number.
  Future<String> _nextLogId(DateTime date) async {
    final dateKey =
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}'
        '${date.year}';
    final counterRef = _firestore.collection('log_counters').doc(dateKey);

    final nextSeq = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final current = (snapshot.data()?['count'] as int?) ?? 0;
      final next = current + 1;
      transaction.set(counterRef, {'count': next});
      return next;
    });

    return 'Logs-$dateKey${nextSeq.toString().padLeft(4, '0')}';
  }

  Future<void> updateEntry(LogEntry entry) async {
    await _collection.doc(entry.id).update({
      ...entry.toMap(),
      'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteEntry(String id) => _collection.doc(id).delete();
}
