import 'dart:io';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../utils/app_formatters.dart';

/// Generates a professionally styled PDF ledger report.
class PdfExportService {
  final Logger _log;

  PdfExportService({Logger? logger}) : _log = logger ?? Logger();

  // ── Brand colours (as PdfColor) ───────────────────────────────────────────
  static const _primaryBlue  = PdfColor.fromInt(0xFF1A56DB);
  static const _successGreen = PdfColor.fromInt(0xFF16A34A);
  static const _dangerRed    = PdfColor.fromInt(0xFFDC2626);
  static const _lightGray    = PdfColor.fromInt(0xFFF3F4F6);
  static const _borderGray   = PdfColor.fromInt(0xFFE5E7EB);
  static const _textDark     = PdfColor.fromInt(0xFF111827);
  static const _textMuted    = PdfColor.fromInt(0xFF6B7280);

  // ── Generate full customer ledger PDF ─────────────────────────────────────

  Future<File> generateCustomerLedger({
    required CustomerEntity customer,
    required List<TransactionEntity> transactions,
    required String businessName,
  }) async {
    final doc  = pw.Document(compress: true);
    final font = await PdfGoogleFonts.poppinsRegular();
    final bold = await PdfGoogleFonts.poppinsBold();
    final mono = await PdfGoogleFonts.sourceCodeProRegular();

    // Chunk transactions per page (max ~25 rows)
    const rowsPerPage = 25;
    final pages = <List<TransactionEntity>>[];
    for (var i = 0; i < transactions.length; i += rowsPerPage) {
      pages.add(transactions.sublist(
          i, (i + rowsPerPage).clamp(0, transactions.length)));
    }
    if (pages.isEmpty) pages.add([]);

    for (var p = 0; p < pages.length; p++) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (p == 0) ...[
              _buildHeader(font, bold, businessName),
              pw.SizedBox(height: 20),
              _buildCustomerCard(font, bold, customer),
              pw.SizedBox(height: 16),
              _buildSummaryRow(font, bold, transactions),
              pw.SizedBox(height: 20),
              _buildTableHeader(bold),
            ] else
              _buildContinuedHeader(font, bold, customer, p + 1),
            _buildTableRows(font, mono, pages[p]),
            pw.Spacer(),
            _buildFooter(font, p + 1, pages.length),
          ],
        ),
      ));
    }

    // Write to temp directory
    final dir  = await getTemporaryDirectory();
    final name = 'LenDen_${customer.name.replaceAll(' ', '_')}_'
        '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(await doc.save());
    _log.i('PDF generated: ${file.path}');
    return file;
  }

  // ── Generate full report PDF ──────────────────────────────────────────────

  Future<File> generateFullReport({
    required List<CustomerEntity> customers,
    required List<TransactionEntity> transactions,
    required String userName,
    required String businessName,
    required DateTime from,
    required DateTime to,
  }) async {
    final doc  = pw.Document(compress: true);
    final font = await PdfGoogleFonts.poppinsRegular();
    final bold = await PdfGoogleFonts.poppinsBold();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        _buildHeader(font, bold, businessName),
        pw.SizedBox(height: 16),
        _buildReportPeriod(font, bold, from, to),
        pw.SizedBox(height: 16),
        _buildReportSummary(font, bold, transactions),
        pw.SizedBox(height: 20),
        _buildCustomerBreakdownTable(font, bold, customers),
        pw.SizedBox(height: 20),
        _buildAllTransactionsTable(font, bold, transactions),
      ],
      footer: (ctx) => _buildFooter(font, ctx.pageNumber, ctx.pagesCount),
    ));

    final dir  = await getTemporaryDirectory();
    final name = 'LenDen_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(await doc.save());
    _log.i('Report PDF generated: ${file.path}');
    return file;
  }

  // ── PDF Widget Builders ───────────────────────────────────────────────────

  pw.Widget _buildHeader(pw.Font font, pw.Font bold, String bizName) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(color: _primaryBlue),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('LenDen',
                style: pw.TextStyle(font: bold, fontSize: 24, color: PdfColors.white)),
            if (bizName.isNotEmpty)
              pw.Text(bizName,
                  style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Ledger Report',
                style: pw.TextStyle(font: bold, fontSize: 13, color: PdfColors.white)),
            pw.Text('Generated: ${AppFormatters.shortDate(DateTime.now())}',
                style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white)),
          ]),
        ],
      ),
    );
  }

  pw.Widget _buildContinuedHeader(
      pw.Font font, pw.Font bold, CustomerEntity c, int page) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Text('${c.name} — continued (page $page)',
          style: pw.TextStyle(font: bold, fontSize: 11, color: _textMuted)),
    );
  }

  pw.Widget _buildCustomerCard(
      pw.Font font, pw.Font bold, CustomerEntity customer) {
    final isCreditor = customer.balance >= 0;
    final balColor   = isCreditor ? _successGreen : _dangerRed;
    final balLabel   = isCreditor
        ? '${customer.name} will give you'
        : 'You will give ${customer.name}';

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGray),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(customer.name,
                style: pw.TextStyle(font: bold, fontSize: 15)),
            pw.Text(customer.phone,
                style: pw.TextStyle(font: font, fontSize: 11, color: _textMuted)),
            if (customer.address != null && customer.address!.isNotEmpty)
              pw.Text(customer.address!,
                  style: pw.TextStyle(font: font, fontSize: 10, color: _textMuted)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(AppFormatters.rupee(customer.absBalance),
                style: pw.TextStyle(font: bold, fontSize: 18, color: balColor)),
            pw.Text(balLabel,
                style: pw.TextStyle(font: font, fontSize: 9, color: balColor)),
          ]),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(
      pw.Font font, pw.Font bold, List<TransactionEntity> txs) {
    final gave = txs.where((t) => t.isGave).fold(0.0, (s, t) => s + t.amount);
    final got  = txs.where((t) => t.isGot ).fold(0.0, (s, t) => s + t.amount);
    final net  = gave - got;

    return pw.Row(children: [
      _summaryBox(font, bold, 'Total Gave', AppFormatters.rupee(gave), _successGreen),
      pw.SizedBox(width: 10),
      _summaryBox(font, bold, 'Total Got',  AppFormatters.rupee(got),  _dangerRed),
      pw.SizedBox(width: 10),
      _summaryBox(font, bold, 'Net Balance',AppFormatters.rupee(net.abs()),
          net >= 0 ? _successGreen : _dangerRed),
    ]);
  }

  pw.Widget _summaryBox(
      pw.Font font, pw.Font bold, String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _lightGray,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(font: font, fontSize: 9, color: _textMuted)),
            pw.SizedBox(height: 3),
            pw.Text(value,
                style: pw.TextStyle(font: bold, fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTableHeader(pw.Font bold) {
    return pw.Container(
      color: _lightGray,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Row(children: [
        pw.Expanded(flex: 2, child: pw.Text('DATE',
            style: pw.TextStyle(font: bold, fontSize: 9, color: _textMuted))),
        pw.Expanded(flex: 3, child: pw.Text('NOTE',
            style: pw.TextStyle(font: bold, fontSize: 9, color: _textMuted))),
        pw.Expanded(flex: 2, child: pw.Text('TYPE',
            style: pw.TextStyle(font: bold, fontSize: 9, color: _textMuted))),
        pw.Expanded(flex: 2, child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('AMOUNT',
              style: pw.TextStyle(font: bold, fontSize: 9, color: _textMuted)),
        )),
      ]),
    );
  }

  pw.Widget _buildTableRows(
      pw.Font font, pw.Font mono, List<TransactionEntity> txs) {
    return pw.Column(
      children: txs.asMap().entries.map((entry) {
        final i      = entry.key;
        final tx     = entry.value;
        final isGave = tx.isGave;
        final color  = isGave ? _successGreen : _dangerRed;
        final sign   = isGave ? '+' : '-';
        final bg     = i.isEven ? PdfColors.white : _lightGray;

        return pw.Container(
          color: bg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Row(children: [
            pw.Expanded(flex: 2, child: pw.Text(
                AppFormatters.shortDate(tx.date),
                style: pw.TextStyle(font: font, fontSize: 9))),
            pw.Expanded(flex: 3, child: pw.Text(
                tx.note?.isNotEmpty == true ? tx.note! : '—',
                style: pw.TextStyle(font: font, fontSize: 9, color: _textMuted))),
            pw.Expanded(flex: 2, child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: isGave
                    ? PdfColor.fromInt(0xFFDCFCE7)
                    : PdfColor.fromInt(0xFFFEE2E2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                  isGave ? 'You Gave' : 'You Got',
                  style: pw.TextStyle(font: font, fontSize: 8, color: color)),
            )),
            pw.Expanded(flex: 2, child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                  '$sign${AppFormatters.rupee(tx.amount)}',
                  style: pw.TextStyle(font: mono, fontSize: 9, color: color)),
            )),
          ]),
        );
      }).toList(),
    );
  }

  pw.Widget _buildReportPeriod(pw.Font font, pw.Font bold, DateTime from, DateTime to) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(color: _lightGray),
      child: pw.Row(children: [
        pw.Text('Report Period: ',
            style: pw.TextStyle(font: bold, fontSize: 11)),
        pw.Text(
            '${AppFormatters.longDate(from)} → ${AppFormatters.longDate(to)}',
            style: pw.TextStyle(font: font, fontSize: 11)),
      ]),
    );
  }

  pw.Widget _buildReportSummary(
      pw.Font font, pw.Font bold, List<TransactionEntity> txs) {
    return _buildSummaryRow(font, bold, txs);
  }

  pw.Widget _buildCustomerBreakdownTable(
      pw.Font font, pw.Font bold, List<CustomerEntity> customers) {
    if (customers.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Customer Breakdown',
            style: pw.TextStyle(font: bold, fontSize: 13)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _borderGray, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _lightGray),
              children: ['CUSTOMER', 'PHONE', 'BALANCE'].map((h) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(h,
                        style: pw.TextStyle(font: bold, fontSize: 9, color: _textMuted)),
                  )).toList(),
            ),
            ...customers.map((c) => pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(c.name, style: pw.TextStyle(font: font, fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(c.phone, style: pw.TextStyle(font: font, fontSize: 9))),
              pw.Padding(padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                      AppFormatters.rupee(c.absBalance),
                      style: pw.TextStyle(
                          font: bold, fontSize: 9,
                          color: c.isCreditor ? _successGreen : _dangerRed))),
            ])),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildAllTransactionsTable(
      pw.Font font, pw.Font bold, List<TransactionEntity> txs) {
    if (txs.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        pw.Text('All Transactions',
            style: pw.TextStyle(font: bold, fontSize: 13)),
        pw.SizedBox(height: 8),
        _buildTableHeader(bold),
        _buildTableRows(font, font, txs),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Font font, int page, int total) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Generated by LenDen App',
            style: pw.TextStyle(font: font, fontSize: 8, color: _textMuted)),
        pw.Text('Page $page of $total',
            style: pw.TextStyle(font: font, fontSize: 8, color: _textMuted)),
      ],
    );
  }
}

/// Provider
final pdfExportServiceProvider = Provider<PdfExportService>((ref) {
  return PdfExportService();
});
