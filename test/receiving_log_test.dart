import 'package:flutter_test/flutter_test.dart';
import 'package:super_printer/features/receiving_log/domain/receiving_invoice.dart';
import 'package:super_printer/features/receiving_log/domain/receiving_item.dart';

void main() {
  group('ReceivingItem', () {
    test('toMap/fromMap round-trip preserves every field', () {
      final item = ReceivingItem(
        id: 'item1',
        invoiceId: 'inv1',
        itemName: 'Salmon Fillet',
        batchCode: 'SF-00001',
        quantity: 10,
        unit: 'lbs',
        temperatureF: 32,
        vendorExpiryDate: DateTime(2026, 9, 15),
        storageLocationId: 'loc1',
        storageLocationName: 'Walk-in Cooler',
        status: ReceivingItemStatus.inStock,
      );

      final restored = ReceivingItem.fromMap('item1', 'inv1', item.toMap());

      expect(restored.itemName, item.itemName);
      expect(restored.quantity, item.quantity);
      expect(restored.unit, item.unit);
      expect(restored.temperatureF, item.temperatureF);
      expect(restored.vendorExpiryDate, item.vendorExpiryDate);
      expect(restored.storageLocationId, item.storageLocationId);
      expect(restored.storageLocationName, item.storageLocationName);
      expect(restored.status, ReceivingItemStatus.inStock);
    });

    test('copyWith to finished/discarded sets the right status and timestamp', () {
      const item = ReceivingItem(
        id: 'item1',
        invoiceId: 'inv1',
        itemName: 'Tuna',
        batchCode: 'TU-00001',
        quantity: 5,
        unit: 'lbs',
      );

      final finished = item.copyWith(
        status: ReceivingItemStatus.finished,
        finishedAt: () => DateTime(2026, 1, 1),
      );
      expect(finished.status, ReceivingItemStatus.finished);
      expect(finished.finishedAt, DateTime(2026, 1, 1));
      expect(finished.discardedAt, isNull);

      final discarded = item.copyWith(
        status: ReceivingItemStatus.discarded,
        discardedAt: () => DateTime(2026, 1, 2),
      );
      expect(discarded.status, ReceivingItemStatus.discarded);
      expect(discarded.discardedAt, DateTime(2026, 1, 2));
    });
  });

  group('ReceivingInvoice', () {
    test('toMap/fromMap round-trip preserves header fields (items are separate)', () {
      final invoice = ReceivingInvoice(
        id: 'inv1',
        invoiceNo: 'INV00001',
        supplierName: 'Grodan',
        receivedAt: DateTime(2026, 2, 7, 10, 30),
        staffId: 'staff1',
        staffName: 'Jhon Doe',
      );

      final restored = ReceivingInvoice.fromMap('inv1', {
        ...invoice.toMap(),
        'createdAtMillis': 1000,
      });

      expect(restored.invoiceNo, invoice.invoiceNo);
      expect(restored.supplierName, invoice.supplierName);
      expect(restored.receivedAt, invoice.receivedAt);
      expect(restored.staffName, invoice.staffName);
      expect(restored.items, isEmpty);
    });

    test('copyWith attaches items without changing header fields', () {
      final invoice = ReceivingInvoice(
        id: 'inv1',
        invoiceNo: 'INV00001',
        supplierName: 'Grodan',
        receivedAt: DateTime(2026, 2, 7),
      );
      const item = ReceivingItem(
        id: 'item1',
        invoiceId: 'inv1',
        itemName: 'Tuna',
        batchCode: 'TU-00001',
        quantity: 5,
        unit: 'lbs',
      );

      final withItems = invoice.copyWith(items: [item]);

      expect(withItems.items, [item]);
      expect(withItems.invoiceNo, invoice.invoiceNo);
      expect(withItems.supplierName, invoice.supplierName);
    });
  });
}
