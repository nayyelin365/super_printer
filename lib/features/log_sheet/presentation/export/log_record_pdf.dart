import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/log_record.dart';
import '../../domain/log_type.dart';
import 'log_record_layout.dart';

/// Sizes each column mainly by its actual **values**, not its header — a
/// long header (e.g. "Results in range (4.1, max 4.2)?") can wrap onto a
/// second header line for free, but a short, fixed-shape value like a date
/// or a pH reading looks broken wrapped mid-word. Giving every long-header
/// column outsized width to fit its header on one line was squeezing the
/// genuinely value-heavy columns (Date, Rice pH) down to just a few points
/// on a wide table like this one — capping the header's contribution fixes
/// that without needing a column-by-column override.
Map<int, pw.TableColumnWidth> _columnWidths(LogExportLayout layout) {
  const headerContributionCap = 10;
  return {
    for (var i = 0; i < layout.headers.length; i++)
      i: pw.FlexColumnWidth(
        [
          layout.rows.isEmpty
              ? 0
              : layout.rows.map((r) => r[i].length).reduce((a, b) => a > b ? a : b),
          layout.headers[i].replaceAll('\n', ' ').length.clamp(0, headerContributionCap),
        ].reduce((a, b) => a > b ? a : b).clamp(4, 20).toDouble(),
      ),
  };
}

/// Builds the landscape, multi-page PDF table for one log's records —
/// matching the Excel export and the paper form. Shared by
/// [shareLogRecordPdf] and [printLogRecordPdf] so both render identically.
pw.Document _buildPdfDocument(LogExportLayout layout) {
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
            columnWidths: _columnWidths(layout),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
      ],
    ),
  );
  return doc;
}

/// Builds a PDF of one log's records and opens the system share sheet —
/// same in-memory pattern as `shareLogRecordExcel` ([XFile.fromData], no
/// print/save-as dialog).
Future<void> shareLogRecordPdf({
  required LogType logType,
  required List<LogRecord> records,
}) async {
  final layout = buildLogExportLayout(logType, records);
  final bytes = await _buildPdfDocument(layout).save();
  final fileName = '${layout.fileStem}.pdf';

  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf'),
      ],
      fileNameOverrides: [fileName],
      subject: '${logType.label} export',
    ),
  );
}

/// Opens the system print / save-as-PDF dialog for one log, instead of the
/// share sheet — for actually printing the page rather than sending it
/// somewhere.
Future<void> printLogRecordPdf({
  required LogType logType,
  required List<LogRecord> records,
}) async {
  final layout = buildLogExportLayout(logType, records);
  final doc = _buildPdfDocument(layout);

  await Printing.layoutPdf(
    onLayout: (format) => doc.save(),
    name: '${layout.fileStem}.pdf',
  );
}
