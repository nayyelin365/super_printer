import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/receiving_invoice.dart';
import '../domain/receiving_item.dart';

/// Firestore-backed storage for Receiving Log invoices and their items.
/// Items live in each invoice's `items` subcollection (the natural fit for
/// "an invoice is the parent record, items are displayed under it"); a
/// `collectionGroup` query watches every item across every invoice in one
/// stream rather than fanning out one listener per invoice, and the UI
/// groups them back by `invoiceId` client-side — see
/// `receiving_log_controller.dart`.
class ReceivingInvoiceRepository {
  ReceivingInvoiceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _invoices =>
      _firestore.collection('receiving_invoices');

  Stream<List<ReceivingInvoice>> watchInvoices() {
    return _invoices.snapshots().map((snapshot) {
      final invoices = snapshot.docs
          .map((doc) => ReceivingInvoice.fromMap(doc.id, doc.data()))
          .toList();
      invoices.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      return invoices;
    });
  }

  /// Every item across every invoice, newest first — filtered/grouped by
  /// `invoiceId` client-side (see the class doc).
  Stream<List<ReceivingItem>> watchAllItems() {
    return _firestore.collectionGroup('items').snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final invoiceId = doc.reference.parent.parent!.id;
        return ReceivingItem.fromMap(doc.id, invoiceId, doc.data());
      }).toList();
      items.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return items;
    });
  }

  Future<ReceivingInvoice> createInvoice(ReceivingInvoice invoice) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final doc = await _invoices.add({...invoice.toMap(), 'createdAtMillis': now});
    return ReceivingInvoice.fromMap(doc.id, {...invoice.toMap(), 'createdAtMillis': now});
  }

  Future<ReceivingItem> addItem(ReceivingItem item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batchCode = await _nextBatchCode(item.itemName);
    final itemsRef = _invoices.doc(item.invoiceId).collection('items');
    final doc = await itemsRef.add({
      ...item.toMap(),
      'batchCode': batchCode,
      'createdAtMillis': now,
    });
    return ReceivingItem.fromMap(doc.id, item.invoiceId, {
      ...item.toMap(),
      'batchCode': batchCode,
      'createdAtMillis': now,
    });
  }

  Future<void> updateItem(ReceivingItem item) => _invoices
      .doc(item.invoiceId)
      .collection('items')
      .doc(item.id)
      .update(item.toMap());

  /// `<initials>-#####` — e.g. "SF-00001" for "Salmon Fillet". The counter
  /// is per-prefix (not global), atomically incremented via the same
  /// transaction pattern as `LogRepository._nextLogId`, so concurrent adds
  /// across devices never collide on the same code.
  Future<String> _nextBatchCode(String itemName) async {
    final words = itemName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join().padRight(2, 'X');

    final counterRef = _firestore.collection('receiving_item_counters').doc(initials);
    final nextSeq = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final current = (snapshot.data()?['count'] as int?) ?? 0;
      final next = current + 1;
      transaction.set(counterRef, {'count': next});
      return next;
    });

    return '$initials-${nextSeq.toString().padLeft(5, '0')}';
  }
}
