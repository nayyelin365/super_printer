/// Status flow for a received item: `inStock -> finished` or
/// `inStock -> discarded`. Once finished/discarded, an item is read-only —
/// no further actions are offered (see `ReceivingLogListScreen`).
enum ReceivingItemStatus {
  inStock('In stock'),
  finished('Finished'),
  discarded('Discarded');

  const ReceivingItemStatus(this.label);
  final String label;
}

/// One item received against a [ReceivingInvoice] — lives in that
/// invoice's `items` subcollection. [itemName] comes from the existing
/// Food catalog (not a separate item-management system), and
/// [storageLocation] from the existing Log Sheet location list, per the
/// "reuse existing components/models" requirement.
class ReceivingItem {
  const ReceivingItem({
    required this.id,
    required this.invoiceId,
    required this.itemName,
    required this.batchCode,
    required this.quantity,
    required this.unit,
    this.temperatureF,
    this.vendorExpiryDate,
    this.storageLocationId,
    this.storageLocationName,
    this.status = ReceivingItemStatus.inStock,
    this.finishedAt,
    this.discardedAt,
    this.createdAt,
  });

  /// Firestore document id — empty string for an item not yet saved.
  final String id;
  final String invoiceId;

  final String itemName;

  /// Auto-generated, human-readable batch code (e.g. "SF-00001") — see
  /// `ReceivingInvoiceRepository._nextBatchCode`.
  final String batchCode;

  final double quantity;
  final String unit;
  final double? temperatureF;
  final DateTime? vendorExpiryDate;

  final String? storageLocationId;
  final String? storageLocationName;

  final ReceivingItemStatus status;
  final DateTime? finishedAt;
  final DateTime? discardedAt;
  final DateTime? createdAt;

  ReceivingItem copyWith({
    String? itemName,
    double? quantity,
    String? unit,
    double? Function()? temperatureF,
    DateTime? Function()? vendorExpiryDate,
    String? Function()? storageLocationId,
    String? Function()? storageLocationName,
    ReceivingItemStatus? status,
    DateTime? Function()? finishedAt,
    DateTime? Function()? discardedAt,
  }) {
    return ReceivingItem(
      id: id,
      invoiceId: invoiceId,
      itemName: itemName ?? this.itemName,
      batchCode: batchCode,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      temperatureF: temperatureF != null ? temperatureF() : this.temperatureF,
      vendorExpiryDate: vendorExpiryDate != null ? vendorExpiryDate() : this.vendorExpiryDate,
      storageLocationId: storageLocationId != null ? storageLocationId() : this.storageLocationId,
      storageLocationName:
          storageLocationName != null ? storageLocationName() : this.storageLocationName,
      status: status ?? this.status,
      finishedAt: finishedAt != null ? finishedAt() : this.finishedAt,
      discardedAt: discardedAt != null ? discardedAt() : this.discardedAt,
      createdAt: createdAt,
    );
  }

  factory ReceivingItem.fromMap(String id, String invoiceId, Map<String, dynamic> data) {
    DateTime? parseDate(String key) =>
        data[key] != null ? DateTime.fromMillisecondsSinceEpoch(data[key] as int) : null;

    return ReceivingItem(
      id: id,
      invoiceId: invoiceId,
      itemName: data['itemName'] as String,
      batchCode: data['batchCode'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      unit: data['unit'] as String? ?? 'lbs',
      temperatureF: (data['temperatureF'] as num?)?.toDouble(),
      vendorExpiryDate: parseDate('vendorExpiryDateMillis'),
      storageLocationId: data['storageLocationId'] as String?,
      storageLocationName: data['storageLocationName'] as String?,
      status: ReceivingItemStatus.values.byName(data['status'] as String? ?? 'inStock'),
      finishedAt: parseDate('finishedAtMillis'),
      discardedAt: parseDate('discardedAtMillis'),
      createdAt: parseDate('createdAtMillis'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'batchCode': batchCode,
      'quantity': quantity,
      'unit': unit,
      if (temperatureF != null) 'temperatureF': temperatureF,
      if (vendorExpiryDate != null)
        'vendorExpiryDateMillis': vendorExpiryDate!.millisecondsSinceEpoch,
      if (storageLocationId != null) 'storageLocationId': storageLocationId,
      if (storageLocationName != null) 'storageLocationName': storageLocationName,
      'status': status.name,
      if (finishedAt != null) 'finishedAtMillis': finishedAt!.millisecondsSinceEpoch,
      if (discardedAt != null) 'discardedAtMillis': discardedAt!.millisecondsSinceEpoch,
    };
  }
}
