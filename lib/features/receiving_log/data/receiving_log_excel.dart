import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/receiving_invoice.dart';

/// Builds an .xlsx of receiving invoices/items and opens the system share
/// sheet — same in-memory pattern as the Log Sheet's `shareLogSheetExcel`.
Future<void> shareReceivingLogExcel({required List<ReceivingInvoice> invoices}) async {
  final workbook = xls.Excel.createExcel();
  final sheetName = workbook.getDefaultSheet()!;
  workbook.rename(sheetName, 'Receiving Log');
  final sheet = workbook['Receiving Log'];

  sheet.appendRow([
    xls.TextCellValue('Invoice No'),
    xls.TextCellValue('Supplier'),
    xls.TextCellValue('Received'),
    xls.TextCellValue('By'),
    xls.TextCellValue('Item'),
    xls.TextCellValue('Batch No'),
    xls.TextCellValue('Quantity/Weight'),
    xls.TextCellValue('Temp'),
    xls.TextCellValue('Vendor Expiry'),
    xls.TextCellValue('Storage Location'),
    xls.TextCellValue('Status'),
  ]);

  final dateFormat = DateFormat('MM/dd/yyyy h:mm a');
  for (final invoice in invoices) {
    for (final item in invoice.items) {
      sheet.appendRow([
        xls.TextCellValue(invoice.invoiceNo),
        xls.TextCellValue(invoice.supplierName),
        xls.TextCellValue(dateFormat.format(invoice.receivedAt)),
        xls.TextCellValue(invoice.staffName ?? ''),
        xls.TextCellValue(item.itemName),
        xls.TextCellValue(item.batchCode),
        xls.TextCellValue('${item.quantity} ${item.unit}'),
        xls.TextCellValue(item.temperatureF == null ? '' : '${item.temperatureF}°F'),
        xls.TextCellValue(
          item.vendorExpiryDate == null
              ? ''
              : DateFormat('MM/dd/yyyy').format(item.vendorExpiryDate!),
        ),
        xls.TextCellValue(item.storageLocationName ?? ''),
        xls.TextCellValue(item.status.label),
      ]);
    }
  }

  final encoded = workbook.encode();
  if (encoded == null) return;
  final bytes = Uint8List.fromList(encoded);

  const fileName = 'Receiving_Log.xlsx';
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          bytes,
          name: fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      fileNameOverrides: [fileName],
      subject: 'Receiving Log export',
    ),
  );
}
