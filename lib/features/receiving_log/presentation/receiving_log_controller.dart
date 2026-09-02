import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/receiving_invoice_repository.dart';
import '../domain/receiving_invoice.dart';
import '../domain/receiving_item.dart';

final receivingInvoiceRepositoryProvider = Provider<ReceivingInvoiceRepository>(
  (ref) => ReceivingInvoiceRepository(),
);

final receivingInvoicesProvider = StreamProvider<List<ReceivingInvoice>>((ref) {
  return ref.watch(receivingInvoiceRepositoryProvider).watchInvoices();
});

final receivingItemsProvider = StreamProvider<List<ReceivingItem>>((ref) {
  return ref.watch(receivingInvoiceRepositoryProvider).watchAllItems();
});

/// Every invoice with its items grouped in client-side (see
/// `ReceivingInvoiceRepository`'s class doc for why) — the shape the list
/// screen actually renders.
final receivingInvoicesWithItemsProvider = Provider<AsyncValue<List<ReceivingInvoice>>>((ref) {
  final invoicesAsync = ref.watch(receivingInvoicesProvider);
  final itemsAsync = ref.watch(receivingItemsProvider);

  if (invoicesAsync.isLoading || itemsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  final error = invoicesAsync.error ?? itemsAsync.error;
  if (error != null) {
    return AsyncValue.error(error, invoicesAsync.stackTrace ?? itemsAsync.stackTrace!);
  }

  final invoices = invoicesAsync.value ?? const [];
  final items = itemsAsync.value ?? const [];
  final byInvoice = <String, List<ReceivingItem>>{};
  for (final item in items) {
    (byInvoice[item.invoiceId] ??= []).add(item);
  }

  return AsyncValue.data([
    for (final invoice in invoices) invoice.copyWith(items: byInvoice[invoice.id] ?? const []),
  ]);
});

class ReceivingLogController {
  ReceivingLogController(this._ref);
  final Ref _ref;

  ReceivingInvoiceRepository get _repository => _ref.read(receivingInvoiceRepositoryProvider);

  Future<ReceivingInvoice> createInvoice({
    required String invoiceNo,
    required String supplierName,
    required DateTime receivedAt,
    required String staffId,
    required String staffName,
  }) {
    return _repository.createInvoice(
      ReceivingInvoice(
        id: '',
        invoiceNo: invoiceNo,
        supplierName: supplierName,
        receivedAt: receivedAt,
        staffId: staffId,
        staffName: staffName,
      ),
    );
  }

  Future<ReceivingItem> addItem({
    required String invoiceId,
    required String itemName,
    required double quantity,
    required String unit,
    double? temperatureF,
    DateTime? vendorExpiryDate,
    String? storageLocationId,
    String? storageLocationName,
  }) {
    return _repository.addItem(
      ReceivingItem(
        id: '',
        invoiceId: invoiceId,
        itemName: itemName,
        batchCode: '',
        quantity: quantity,
        unit: unit,
        temperatureF: temperatureF,
        vendorExpiryDate: vendorExpiryDate,
        storageLocationId: storageLocationId,
        storageLocationName: storageLocationName,
      ),
    );
  }

  Future<void> updateItem(ReceivingItem item) => _repository.updateItem(item);

  Future<void> finishItem(ReceivingItem item) => _repository.updateItem(
    item.copyWith(status: ReceivingItemStatus.finished, finishedAt: () => DateTime.now()),
  );

  Future<void> discardItem(ReceivingItem item) => _repository.updateItem(
    item.copyWith(status: ReceivingItemStatus.discarded, discardedAt: () => DateTime.now()),
  );
}

final receivingLogControllerProvider = Provider<ReceivingLogController>(
  (ref) => ReceivingLogController(ref),
);
