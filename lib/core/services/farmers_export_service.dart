import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import '../constants/app_constants.dart';

/// Plain row used for exporting (keeps the service independent of the UI).
class ExportFarmer {
  final String name;
  final String phone;
  final String location;
  final double advances;
  final bool active;
  const ExportFarmer({
    required this.name,
    required this.phone,
    required this.location,
    required this.advances,
    required this.active,
  });
}

/// Exports the farmers list as a PDF report or an Excel (.xlsx) sheet.
class FarmersExportService {
  static String _stamp() => DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

  // ───────────────────────── PDF ─────────────────────────

  static Future<void> exportPdf(List<ExportFarmer> farmers) async {
    const ink = PdfColor.fromInt(0xFF14231B);
    const muted = PdfColor.fromInt(0xFF4F5C54);
    const line = PdfColor.fromInt(0xFFCBD5CF);
    const headBg = PdfColor.fromInt(0xFFEAF7E4);
    const stripe = PdfColor.fromInt(0xFFF8FAF9);
    const red = PdfColor.fromInt(0xFFD93036);
    const green = PdfColor.fromInt(0xFF2E8B1A);

    final money = NumberFormat('#,##0');
    final total = farmers.fold<double>(0, (s, f) => s + f.advances);
    final active = farmers.where((f) => f.active).length;
    final withAdv = farmers.where((f) => f.advances > 0).length;
    final generated = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

    pw.Widget cell(
      String text, {
      bool bold = false,
      pw.Alignment align = pw.Alignment.centerLeft,
      PdfColor color = ink,
      double size = 9.5,
    }) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      );
    }

    pw.Widget statBox(String label, String value) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: line, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 9, color: muted)),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: ink)),
            ],
          ),
        ),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: headBg),
        children: [
          cell('#', bold: true),
          cell('Farmer', bold: true),
          cell('Phone', bold: true),
          cell('Location', bold: true),
          cell('Advances (UGX)', bold: true, align: pw.Alignment.centerRight),
          cell('Status', bold: true),
        ],
      ),
      for (var i = 0; i < farmers.length; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: i.isOdd ? stripe : PdfColors.white),
          children: [
            cell('${i + 1}', color: muted),
            cell(farmers[i].name, bold: true),
            cell(farmers[i].phone),
            cell(farmers[i].location),
            cell(
              farmers[i].advances > 0 ? money.format(farmers[i].advances) : '-',
              align: pw.Alignment.centerRight,
              color: farmers[i].advances > 0 ? red : muted,
              bold: farmers[i].advances > 0,
            ),
            cell(farmers[i].active ? 'Active' : 'Inactive',
                color: farmers[i].active ? green : muted, bold: true),
          ],
        ),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: headBg),
        children: [
          cell(''),
          cell('Total (${farmers.length})', bold: true),
          cell(''),
          cell(''),
          cell(money.format(total),
              bold: true, color: red, align: pw.Alignment.centerRight),
          cell(''),
        ],
      ),
    ];

    final pdf = pw.Document(title: 'Farmers Report');
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${AppConstants.companyNameShort}  |  Generated $generated',
                style: const pw.TextStyle(fontSize: 8, color: muted)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
        build: (ctx) => [
          pw.Text(AppConstants.companyNameShort,
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: ink)),
          pw.SizedBox(height: 2),
          pw.Text('Farmers Report',
              style: const pw.TextStyle(fontSize: 12, color: muted)),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              statBox('Total farmers', '${farmers.length}'),
              pw.SizedBox(width: 10),
              statBox('Active', '$active'),
              pw.SizedBox(width: 10),
              statBox('With advances', '$withAdv'),
              pw.SizedBox(width: 10),
              statBox('Advances given (UGX)', money.format(total)),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: line, width: 0.6),
            columnWidths: const {
              0: pw.FixedColumnWidth(30),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(2.2),
              3: pw.FlexColumnWidth(3),
              4: pw.FlexColumnWidth(2.2),
              5: pw.FlexColumnWidth(1.4),
            },
            children: rows,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    await FileSaver.instance.saveFile(
      name: 'farmers_${_stamp()}',
      bytes: bytes,
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  // ───────────────────────── Excel ─────────────────────────

  static Future<void> exportExcel(List<ExportFarmer> farmers) async {
    final excel = xl.Excel.createExcel();
    excel.rename('Sheet1', 'Farmers');
    final sheet = excel['Farmers'];

    final head = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#EAF7E4'),
      fontColorHex: xl.ExcelColor.fromHexString('#14231B'),
    );
    final bold = xl.CellStyle(bold: true);

    final headers = ['#', 'Farmer', 'Phone', 'Location', 'Advances (UGX)', 'Status'];
    sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());
    for (var c = 0; c < headers.length; c++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = head;
    }

    for (var i = 0; i < farmers.length; i++) {
      final f = farmers[i];
      sheet.appendRow([
        xl.IntCellValue(i + 1),
        xl.TextCellValue(f.name),
        xl.TextCellValue(f.phone),
        xl.TextCellValue(f.location),
        xl.DoubleCellValue(f.advances),
        xl.TextCellValue(f.active ? 'Active' : 'Inactive'),
      ]);
    }

    final total = farmers.fold<double>(0, (s, f) => s + f.advances);
    sheet.appendRow([
      xl.TextCellValue(''),
      xl.TextCellValue('Total (${farmers.length})'),
      xl.TextCellValue(''),
      xl.TextCellValue(''),
      xl.DoubleCellValue(total),
      xl.TextCellValue(''),
    ]);
    final totalRow = farmers.length + 1;
    for (var c = 0; c < headers.length; c++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRow))
          .cellStyle = bold;
    }

    const widths = [6.0, 26.0, 18.0, 28.0, 18.0, 12.0];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Could not build the Excel file');
    await FileSaver.instance.saveFile(
      name: 'farmers_${_stamp()}',
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }
}
