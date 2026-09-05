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
      batches.sort(_byCreatedAtDesc);
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
      batches.sort((a, b) => _byCreatedAtDesc(b, a));
      return batches;
    });
  }

  /// Newest first. Sorts by `soakStartedAt` (always set at creation) rather
  /// than `batchCode` — the code's `RICA-MMDD-##` format resets its
  /// sequence every day and drops the year, so a plain string compare would
  /// order batches wrong across a day or year boundary.
  int _byCreatedAtDesc(SushiRiceBatch a, SushiRiceBatch b) {
    final aTime = a.soakStartedAt;
    final bTime = b.soakStartedAt;
    if (aTime == null || bTime == null) return b.batchCode.compareTo(a.batchCode);
    return bTime.compareTo(aTime);
  }

  /// Looks up one batch by its printed `batchCode` (what the label's QR
  /// code actually encodes — not the Firestore doc id) — used by "Scan QR
  /// on Label" to jump straight to that batch's detail page. A single
  /// equality `where`, no `orderBy`, so no composite index is needed.
  Future<SushiRiceBatch?> findByBatchCode(String batchCode) async {
    final snapshot = await _collection.where('batchCode', isEqualTo: batchCode).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return SushiRiceBatch.fromMap(doc.id, doc.data());
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

  /// `RICA-MMDD-##` — a per-day, atomically-incrementing counter (same
  /// transaction pattern as `LogRepository._nextLogId`), so concurrent
  /// batch creation across devices never collides. The counter document is
  /// keyed by the full date (`yyyyMMdd`), not just `MMDD`, so the sequence
  /// still resets cleanly at year boundaries without two different years'
  /// Sep 4ths sharing a counter.
  Future<String> _nextBatchCode() async {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final dateKey = '${now.year}$mm$dd';
    final counterRef = _firestore.collection('sushi_rice_batch_counters').doc(dateKey);

    final nextSeq = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final current = (snapshot.data()?['count'] as int?) ?? 0;
      final next = current + 1;
      transaction.set(counterRef, {'count': next});
      return next;
    });

    return 'RICA-$mm$dd-${nextSeq.toString().padLeft(2, '0')}';
  }

  Future<void> update(SushiRiceBatch batch) => _collection.doc(batch.id).update(batch.toMap());

  Future<void> delete(String id) => _collection.doc(id).delete();
}
