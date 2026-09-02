import 'receiving_item.dart';

/// One supplier invoice — the parent record for one or more
/// [ReceivingItem]s (its `items` Firestore subcollection). An invoice must
/// exist before items can be added to it.
class ReceivingInvoice {
  const ReceivingInvoice({
    required this.id,
    required this.invoiceNo,
    required this.supplierName,
    required this.receivedAt,
    this.staffId,
    this.staffName,
    this.createdAt,
    this.items = const [],
  });

  /// Firestore document id — empty string for an invoice not yet saved.
  final String id;

  final String invoiceNo;
  final String supplierName;
  final DateTime receivedAt;

  final String? staffId;
  final String? staffName;

  final DateTime? createdAt;

  /// Loaded alongside the invoice by the repository/controller — not part
  /// of the invoice document itself (items live in a subcollection).
  final List<ReceivingItem> items;

  ReceivingInvoice copyWith({List<ReceivingItem>? items}) {
    return ReceivingInvoice(
      id: id,
      invoiceNo: invoiceNo,
      supplierName: supplierName,
      receivedAt: receivedAt,
      staffId: staffId,
      staffName: staffName,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }

  factory ReceivingInvoice.fromMap(String id, Map<String, dynamic> data) {
    return ReceivingInvoice(
      id: id,
      invoiceNo: data['invoiceNo'] as String,
      supplierName: data['supplierName'] as String,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(data['receivedAtMillis'] as int),
      staffId: data['staffId'] as String?,
      staffName: data['staffName'] as String?,
      createdAt: data['createdAtMillis'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAtMillis'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceNo': invoiceNo,
      'supplierName': supplierName,
      'receivedAtMillis': receivedAt.millisecondsSinceEpoch,
      if (staffId != null) 'staffId': staffId,
      if (staffName != null) 'staffName': staffName,
    };
  }
}
