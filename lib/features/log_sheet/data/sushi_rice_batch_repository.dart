import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/sushi_rice_batch.dart';

/// Firestore-backed storage for Sushi Rice SOP batches — multiple batches
/// are tracked concurrently (the dashboard shows all of them), so this
/// lives in Firestore rather than local storage: every device needs to see
/// the same in-progress batches.
class SushiRiceBatchRepository {
  SushiRiceBatchRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('sushi_rice_batches');

  /// Every batch that hasn't finished/been discarded yet, newest first.
  /// Filters client-side (not a `where` clause) to avoid needing a
  /// composite index for the sort — same reasoning as
  /// `LogRepository.watchEntries`.
  Stream<List<SushiRiceBatch>> watchActive() {
    return _collection.snapshots().map((snapshot) {
      final batches = snapshot.docs
          .map((doc) => SushiRiceBatch.fromMap(doc.id, doc.data()))
          .where((b) => b.finishedAt == null)
          .toList();
      batches.sort((a, b) => b.batchCode.compareTo(a.batchCode));
      return batches;
    });
  }

  /// Every batch ever created (including finished/discarded ones), oldest
  /// first — for the "Sushi Rice pH Log Sheet" HACCP report, which is a
  /// historical record, not a work queue.
  Stream<List<SushiRiceBatch>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      final batches = snapshot.docs
          .map((doc) => SushiRiceBatch.fromMap(doc.id, doc.data()))
          .toList();
      batches.sort((a, b) => a.batchCode.compareTo(b.batchCode));
      return batches;
    });
  }

  Stream<SushiRiceBatch?> watchOne(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SushiRiceBatch.fromMap(doc.id, doc.data()!);
    });
  }

  Future<SushiRiceBatch> create(SushiRiceBatch batch) async {
    final batchCode = await _nextBatchCode();
    final doc = await _collection.add({...batch.toMap(), 'batchCode': batchCode});
    return SushiRiceBatch.fromMap(doc.id, {...batch.toMap(), 'batchCode': batchCode});
  }

  /// `Batch-YYYY-####` — a per-year, atomically-incrementing counter (same
  /// transaction pattern as `LogRepository._nextLogId`), so concurrent
  /// batch creation across devices never collides.
  Future<String> _nextBatchCode() async {
    final year = DateTime.now().year;
    final counterRef = _firestore.collection('sushi_rice_batch_counters').doc(year.toString());

    final nextSeq = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final current = (snapshot.data()?['count'] as int?) ?? 0;
      final next = current + 1;
      transaction.set(counterRef, {'count': next});
      return next;
    });

    return 'Batch-$year-${nextSeq.toString().padLeft(4, '0')}';
  }

  Future<void> update(SushiRiceBatch batch) => _collection.doc(batch.id).update(batch.toMap());

  Future<void> delete(String id) => _collection.doc(id).delete();
}
