import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/cooling_record.dart';
import '../domain/log_record.dart';
import '../domain/log_type.dart';
import '../domain/rice_hot_hold_record.dart';
import '../domain/sushi_bar_temp_record.dart';
import '../domain/sushi_rice_ph_record.dart';

/// Firestore-backed storage for the four kitchen logs — one collection
/// (`log_records`) shared by every [LogType], filtered by the `logType`
/// field. Each [LogRecord] serializes through its own `toMap()`; reads
/// dispatch back to the matching concrete type by that same field.
///
/// Queries only filter by `logType` (a single-field equality, auto-indexed)
/// and sort client-side by date/time — deliberately avoiding a
/// `where(logType) + orderBy(date)` composite that would need a
/// manually-created Firestore index this environment can't deploy.
class LogRecordRepository {
  LogRecordRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('log_records');

  static LogRecord _fromDoc(String id, Map<String, dynamic> data) {
    final type = LogType.values.byName(data['logType'] as String);
    return switch (type) {
      LogType.sushiRicePh => SushiRicePhRecord.fromMap(id, data),
      LogType.sushiBarTemp => SushiBarTempRecord.fromMap(id, data),
      LogType.cooling => CoolingRecord.fromMap(id, data),
      LogType.riceHotHold => RiceHotHoldRecord.fromMap(id, data),
    };
  }

  /// Live updates for every record of [logType], newest first
  /// (date descending, then time within the day descending).
  Stream<List<LogRecord>> watchRecords(LogType logType) {
    return _collection.where('logType', isEqualTo: logType.id).snapshots().map((snapshot) {
      final records = snapshot.docs.map((doc) => _fromDoc(doc.id, doc.data())).toList();
      records.sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        return b.timeSortKey.compareTo(a.timeSortKey);
      });
      return records;
    });
  }

  Future<void> addRecord(LogRecord record) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final docId = await _nextRecordId(record.logType, record.date);
    await _collection.doc(docId).set({
      ...record.toMap(),
      'createdAtMillis': now,
      'updatedAtMillis': now,
    });
  }

  Future<void> updateRecord(LogRecord record) async {
    await _collection.doc(record.id).set({
      ...record.toMap(),
      'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  Future<void> deleteRecord(String id) => _collection.doc(id).delete();

  /// Human-readable sequential document id — `<PREFIX>-MMDDYYYY####`
  /// (e.g. `COOL-0823202600001`). The per-day counter lives in its own
  /// `log_record_counters/{PREFIX-MMDDYYYY}` document, incremented inside a
  /// transaction so concurrent saves from different devices never collide.
  /// Copied from `LogRepository._nextLogId`.
  Future<String> _nextRecordId(LogType logType, DateTime date) async {
    final dateKey = '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}'
        '${date.year}';
    final counterKey = '${logType.idPrefix}-$dateKey';
    final counterRef = _firestore.collection('log_record_counters').doc(counterKey);

    final nextSeq = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final current = (snapshot.data()?['count'] as int?) ?? 0;
      final next = current + 1;
      transaction.set(counterRef, {'count': next});
      return next;
    });

    return '${logType.idPrefix}-$dateKey${nextSeq.toString().padLeft(5, '0')}';
  }
}
