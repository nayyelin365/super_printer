import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/log_record.dart';
import '../../domain/log_type.dart';
import 'log_record_layout.dart';

/// Opens the system print / save-as-PDF dialog for one log — a landscape,
/// multi-page table matching the Excel export and the paper form. Same
/// `pw.Document` + `Printing.layoutPdf` pattern as the old
/// `printLogSheetPdf`.
Future<void> printLogRecordPdf({
  required LogType logType,
  required List<LogRecord> records,
}) async {
  final layout = buildLogExportLayout(logType, records);
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            layout.title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          for (final line in layout.infoLines)
            pw.Text(line, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
        ],
      ),
      build: (context) => [
        if (layout.rows.isEmpty)
          pw.Text('No entries.', style: const pw.TextStyle(fontSize: 10))
        else
          pw.TableHelper.fromTextArray(
            headers: [for (final h in layout.headers) h.replaceAll('\n', ' ')],
            data: layout.rows,
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) => doc.save(),
    name: '${layout.fileStem}.pdf',
  );
}
