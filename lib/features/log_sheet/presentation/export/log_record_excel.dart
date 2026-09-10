import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:share_plus/share_plus.dart';

import '../../domain/log_record.dart';
import '../../domain/log_type.dart';
import 'log_record_layout.dart';

/// Builds an .xlsx of one log's records and opens the system share sheet —
/// same in-memory pattern as `shareReceivingLogExcel` / the old
/// `shareLogSheetExcel` ([XFile.fromData], no temp file). Layout comes from
/// [buildLogExportLayout] so it matches the PDF export and the paper form.
Future<void> shareLogRecordExcel({
  required LogType logType,
  required List<LogRecord> records,
}) async {
  final layout = buildLogExportLayout(logType, records);

  final workbook = xls.Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet()!;
  workbook.rename(defaultSheet, logType.label);
  final sheet = workbook[logType.label];

  sheet.appendRow([xls.TextCellValue(layout.title)]);
  for (final line in layout.infoLines) {
    sheet.appendRow([xls.TextCellValue(line)]);
  }
  sheet.appendRow([]);

  sheet.appendRow([for (final h in layout.headers) xls.TextCellValue(h.replaceAll('\n', ' '))]);
  for (final row in layout.rows) {
    sheet.appendRow([for (final cell in row) xls.TextCellValue(cell)]);
  }

  final encoded = workbook.encode();
  if (encoded == null) return;
  final bytes = Uint8List.fromList(encoded);
  final fileName = '${layout.fileStem}.xlsx';

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
      subject: '${logType.label} export',
    ),
  );
}
