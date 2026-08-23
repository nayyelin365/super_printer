import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/log_entry.dart';
import '../../domain/log_type.dart';

/// Opens the system print/save-as-PDF dialog for [entries] — a landscape,
/// multi-page table matching the on-screen log sheet columns.
/// [filterSummary] (e.g. "Date: 08/23/2026 · Location: Walk-in Cooler") is
/// printed under the title so an exported/printed sheet still shows what
/// it was filtered to.
Future<void> printLogSheetPdf({
  required LogType logType,
  required List<LogEntry> entries,
  String? filterSummary,
}) async {
  final doc = pw.Document();

  const headers = [
    'Date',
    'Time',
    'Food',
    'Unit Name / Location',
    'Target Temp',
    'Actual Temp',
    'Pass/Fail',
    'Corrective Action',
    'Initials',
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            logType.label,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          if (filterSummary != null && filterSummary.isNotEmpty)
            pw.Text(
              filterSummary,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          pw.SizedBox(height: 8),
        ],
      ),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: [
            for (final e in entries)
              [
                e.dateLabel,
                e.timeLabel,
                e.foodName,
                e.locationName,
                e.targetTempLabel,
                e.actualTempLabel,
                e.passFail.label,
                e.correctiveActionLabel,
                e.initials,
              ],
          ],
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) => doc.save(),
    name: '${logType.label}.pdf',
  );
}
