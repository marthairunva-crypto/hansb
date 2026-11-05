import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import '../constants/app_constants.dart';
import '../../domain/services/business_settings_service.dart';
import '../../data/models/business_settings.dart';

/// Thermal-printer receipts (58mm roll by default, 80mm supported).
///
/// Design rules for thermal paper:
///  - black on white only (no colour fills, they print as heavy blobs)
///  - plain ASCII text (the built-in PDF fonts have no special glyphs)
///  - page height equals the content height, so there is no wasted paper
///
/// Flow: the receipt is first shown in an in-app PREVIEW dialog. Printing
/// only happens when the user presses Print inside that preview.
class ReceiptService {
  static const double _mm = PdfPageFormat.mm;
  static const PdfColor _ink = PdfColors.black;
  static const PdfColor _soft = PdfColor.fromInt(0xFF444444);

  // ───────────────────────── Public API ─────────────────────────

  /// Pass [context] to get the preview dialog first (recommended).
  /// Without a context it falls back to the browser/system print dialog.
  static Future<void> generatePurchaseReceipt({
    required String receiptNumber,
    required String farmerName,
    required String farmerPhone,
    required double grossWeight,
    required double deductionPercentage,
    required double deductionWeight,
    required double payableWeight,
    required double pricePerKg,
    required double millingCharge,
    required double netPayment,
    required double advanceDeducted,
    required String date,
    String? branchName,
    String? branchLocation,
    double paperWidthMm = 58,
    BuildContext? context,
  }) async {
    final businessSettings = await BusinessSettingsService.instance.getSettings();

    final layout = _Layout(paperWidthMm);
    final pdf = pw.Document(title: 'Receipt $receiptNumber');

    pdf.addPage(
      pw.Page(
        pageFormat: layout.format,
        margin: layout.margin,
        build: (pdfContext) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            ..._header(layout, businessSettings, branchName: branchName, branchLocation: branchLocation),
            pw.SizedBox(height: 2),
            pw.Text(
              'PURCHASE RECEIPT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 2),
            _dashed(layout),
            _row('No', receiptNumber, valueBold: true, compact: true),
            _row('Date', date, compact: true),
            _row('Client', farmerName, valueBold: true, compact: true),
            if (farmerPhone.isNotEmpty) _row('Phone', farmerPhone, compact: true),
            _dashed(layout),
            _heading('WEIGHT', compact: true),
            _row('Gross', _kg(grossWeight), compact: true),
            _row('Deduct (${deductionPercentage.toStringAsFixed(1)}%)',
                '- ${_kg(deductionWeight)}',
                compact: true),
            _solid(),
            _row('Payable', _kg(payableWeight),
                bold: true, size: 8.5, compact: true),
            _dashed(layout),
            _heading('PAYMENT', compact: true),
            _row('Price/kg', _ugx(pricePerKg), compact: true),
            _row('Subtotal', _ugx(payableWeight * pricePerKg), compact: true),
            _row('Milling', '- ${_ugx(millingCharge)}', compact: true),
            if (advanceDeducted > 0)
              _row('Advance', '- ${_ugx(advanceDeducted)}', compact: true),
            pw.SizedBox(height: 1.5),
            _totalBox('NET', _ugx(netPayment)),
            pw.SizedBox(height: 2),
            // Add barcode
            ..._barcode(receiptNumber, layout),
            pw.SizedBox(height: 2),
            _signatureLine('Client signature'),
            pw.SizedBox(height: 2),
            ..._footer(layout, businessSettings, thanks: 'Thank you!'),
          ],
        ),
      ),
    );

    await _present(
      context,
      title: 'Receipt $receiptNumber',
      fileName: 'Receipt-$receiptNumber',
      format: layout.format,
      bytes: await pdf.save(),
    );
  }

  static Future<void> generateAdvanceReceipt({
    required String receiptNumber,
    required String farmerName,
    required String farmerPhone,
    required double amount,
    required String purpose,
    required String date,
    double paperWidthMm = 58,
    BuildContext? context,
  }) async {
    final businessSettings = await BusinessSettingsService.instance.getSettings();

    final layout = _Layout(paperWidthMm);
    final pdf = pw.Document(title: 'Advance $receiptNumber');

    pdf.addPage(
      pw.Page(
        pageFormat: layout.format,
        margin: layout.margin,
        build: (pdfContext) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            ..._header(layout, businessSettings),
            pw.SizedBox(height: 4),
            _titleBox('ADVANCE RECEIPT'),
            pw.SizedBox(height: 4),
            _row('Receipt No', receiptNumber, valueBold: true, compact: true),
            _row('Date', date, valueBold: true, compact: true),
            _row('Received by', farmerName, valueBold: true, compact: true),
            if (farmerPhone.isNotEmpty) _row('Phone', farmerPhone, compact: true),
            pw.SizedBox(height: 3),
            _dashed(layout),
            _heading('PURPOSE', compact: true),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                purpose.isEmpty ? '-' : purpose,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            pw.SizedBox(height: 2),
            _totalBox('ADVANCE AMOUNT', _ugx(amount)),
            pw.SizedBox(height: 5),
            pw.Text(
              'This advance will be deducted from future coffee purchases.',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _soft,
              ),
            ),
            pw.SizedBox(height: 10),
            _signatureLine('Client signature'),
            pw.SizedBox(height: 8),
            _signatureLine('Authorised by'),
            pw.SizedBox(height: 4),
            ..._footer(layout, businessSettings,
                thanks: 'Keep this receipt safely.'),
          ],
        ),
      ),
    );

    await _present(
      context,
      title: 'Advance $receiptNumber',
      fileName: 'Advance-$receiptNumber',
      format: layout.format,
      bytes: await pdf.save(),
    );
  }

  // ───────────────────────── Preview / print ─────────────────────────

  /// Shows the receipt in a preview dialog first. Nothing is printed until the
  /// user presses Print inside the preview.
  static Future<void> _present(
    BuildContext? context, {
    required String title,
    required String fileName,
    required PdfPageFormat format,
    required Uint8List bytes,
  }) async {
    // No context available -> old behaviour (system print dialog)
    if (context == null || !context.mounted) {
      await Printing.layoutPdf(
        name: fileName,
        format: format,
        onLayout: (_) async => bytes,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final h = math.min(MediaQuery.of(ctx).size.height * 0.92, 760.0);
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: SizedBox(
            width: 420,
            height: h,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Receipt Preview',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: PdfPreview(
                    build: (_) async => bytes,
                    initialPageFormat: format,
                    pageFormats: {'Receipt': format},
                    pdfFileName: '$fileName.pdf',
                    allowPrinting: true,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    maxPageWidth: 300,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────── Sections ─────────────────────────

  static List<pw.Widget> _header(_Layout layout, BusinessSettings settings, {
    String? branchName,
    String? branchLocation,
  }) {
    // Determine what location to show - prioritize branch location
    String locationText;
    if (branchLocation != null && branchLocation.isNotEmpty) {
      // Show branch location (e.g., "Mbale" or "Kampala")
      locationText = '$branchLocation | Tel: ${settings.phone}';
    } else if (settings.city.isNotEmpty) {
      // Show headquarters city
      locationText = '${settings.city} | Tel: ${settings.phone}';
    } else {
      // Fallback to just phone
      locationText = 'Tel: ${settings.phone}';
    }
    
    return [
      pw.Text(
        settings.companyNameShort.toUpperCase(),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.3,
          color: _ink,
        ),
      ),
      if (branchName != null && branchName.isNotEmpty) ...[
        pw.SizedBox(height: 1),
        pw.Text(
          branchName.toUpperCase(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.2,
            color: _ink,
          ),
        ),
      ],
      pw.SizedBox(height: 1.5),
      pw.Text(
        locationText,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
      pw.SizedBox(height: 2),
      _dashed(layout, ch: '='),
    ];
  }

  static List<pw.Widget> _barcode(String data, _Layout layout) {
    if (data.trim().isEmpty) return const [];
    return [
      pw.Center(
        child: pw.BarcodeWidget(
          barcode: pw.Barcode.code128(),
          data: data,
          width: layout.usableWidth * 0.6,
          height: 20,
          drawText: false,
          color: _ink,
        ),
      ),
      pw.SizedBox(height: 1.5),
      pw.Text(
        data,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    ];
  }

  static List<pw.Widget> _footer(_Layout layout, BusinessSettings settings,
      {required String thanks}) {
    return [
      _dashed(layout),
      pw.Text(
        thanks,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
      pw.SizedBox(height: 1.5),
      pw.Text(
        'Powered by Infinitech',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
      pw.SizedBox(height: 2),
    ];
  }

  // ───────────────────────── Building blocks ─────────────────────────

  static pw.Widget _titleBox(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _ink, width: 1.2),
      ),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.5,
          color: _ink,
        ),
      ),
    );
  }

  static pw.Widget _heading(String text, {bool compact = false}) {
    return pw.Padding(
      padding:
          pw.EdgeInsets.only(top: compact ? 2.5 : 6, bottom: compact ? 2 : 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: compact ? 8.5 : 10,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: compact ? 0.8 : 1.2,
          color: _ink,
        ),
      ),
    );
  }

  static pw.Widget _row(
    String label,
    String value, {
    bool bold = false,
    bool valueBold = false,
    double size = 10,
    bool compact = false,
  }) {
    final effectiveSize = compact ? 8.5 : size;
    // Make EVERYTHING bold for thermal printing clarity
    final labelStyle = pw.TextStyle(
      fontSize: effectiveSize,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    );
    final valueStyle = pw.TextStyle(
      fontSize: effectiveSize,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    );
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: compact ? 1.2 : 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: labelStyle),
          pw.SizedBox(width: compact ? 4 : 8),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _ink, width: 1.2),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
              color: _ink,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureLine(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(height: 0.6, color: _ink),
        pw.SizedBox(height: 1.5),
        pw.Text(
          label,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 6.5,
            fontWeight: pw.FontWeight.bold, // Bold for thermal
            color: _soft,
          ),
        ),
      ],
    );
  }

  static pw.Widget _solid() => pw.Container(height: 0.8, color: _ink);

  /// Dashed / double rule drawn with a monospace font so it always spans
  /// the full printable width of the paper.
  static pw.Widget _dashed(_Layout layout, {String ch = '-'}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text(
        ch * layout.ruleChars,
        maxLines: 1,
        style: pw.TextStyle(
          font: pw.Font.courier(),
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    );
  }

  // ───────────────────────── Formatting ─────────────────────────

  static String _ugx(double v) => 'UGX ${NumberFormat('#,##0').format(v)}';
  static String _kg(double v) => '${NumberFormat('#,##0.00').format(v)} kg';
}

/// Paper geometry for a thermal roll.
/// Height is infinite so the page is exactly as tall as the receipt content.
class _Layout {
  final double widthMm;
  _Layout(this.widthMm);

  late final PdfPageFormat format =
      PdfPageFormat(widthMm * PdfPageFormat.mm, double.infinity);

  // Tight margins: almost no blank paper above or below the text.
  late final pw.EdgeInsets margin = pw.EdgeInsets.fromLTRB(
    4 * PdfPageFormat.mm,
    2 * PdfPageFormat.mm,
    4 * PdfPageFormat.mm,
    4 * PdfPageFormat.mm,
  );

  double get usableWidth => widthMm * PdfPageFormat.mm - 8 * PdfPageFormat.mm;

  /// Courier 8pt is 4.8pt wide per character.
  int get ruleChars => (usableWidth / 4.8).floor();
}