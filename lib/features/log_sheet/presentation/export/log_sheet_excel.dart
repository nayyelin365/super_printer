import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:share_plus/share_plus.dart';

import '../../domain/log_entry.dart';
import '../../domain/log_type.dart';

/// Builds an .xlsx workbook of [entries] and opens the system share sheet
/// so it can be saved/emailed/etc — entirely in memory, no temp file
/// needed ([XFile.fromData]).
Future<void> shareLogSheetExcel({required LogType logType, required List<LogEntry> entries}) async {
  final workbook = xls.Excel.createExcel();
  final sheetName = workbook.getDefaultSheet()!;
  workbook.rename(sheetName, logType.label);
  final sheet = workbook[logType.label];

  sheet.appendRow([
    xls.TextCellValue('Date'),
    xls.TextCellValue('Time'),
    xls.TextCellValue('Food'),
    xls.TextCellValue('Unit Name / Location'),
    xls.TextCellValue('Target Temp'),
    xls.TextCellValue('Actual Temp'),
    xls.TextCellValue('Pass/Fail'),
    xls.TextCellValue('Corrective Action'),
    xls.TextCellValue('Initials'),
  ]);

  for (final entry in entries) {
    sheet.appendRow([
      xls.TextCellValue(entry.dateLabel),
      xls.TextCellValue(entry.timeLabel),
      xls.TextCellValue(entry.foodName),
      xls.TextCellValue(entry.locationName),
      xls.TextCellValue(entry.targetTempLabel),
      xls.TextCellValue(entry.actualTempLabel),
      xls.TextCellValue(entry.passFail.label),
      xls.TextCellValue(entry.correctiveActionLabel),
      xls.TextCellValue(entry.initials),
    ]);
  }

  final encoded = workbook.encode();
  if (encoded == null) return;
  final bytes = Uint8List.fromList(encoded);

  final fileName = '${logType.label.replaceAll(' ', '_')}.xlsx';
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
