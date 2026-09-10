import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/customer_case.dart';

class ReceiptService {
  static Future<void> generateAndDownloadReceipt({
    required CustomerCase item,
    required double amount,
    required String remark,
  }) async {
    try {
      final pdf = await _createPdf(item, amount, remark);
      final bytes = await pdf.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'SAFL_Receipt_${item.loanNo}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint("Receipt Error: $e");
    }
  }

  static Future<void> generateAndPrintReceipt({
    required CustomerCase item,
    required double amount,
    required String remark,
  }) async {
    try {
      final pdf = await _createPdf(item, amount, remark);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'SAFL_Receipt_${item.loanNo}',
      );
    } catch (e) {
      debugPrint("Print Error: $e");
    }
  }

  static Future<pw.Document> _createPdf(
    CustomerCase item,
    double amount,
    String remark,
  ) async {
    final pdf = pw.Document();

    pw.Font? englishFont;
    pw.Font? englishBold;
    pw.Font? hindiFont;
    pw.Font? hindiBold;

    try {
      englishFont = await PdfGoogleFonts.robotoRegular();
      englishBold = await PdfGoogleFonts.robotoBold();
      hindiFont = await PdfGoogleFonts.notoSansDevanagariRegular();
      hindiBold = await PdfGoogleFonts.notoSansDevanagariBold();
    } catch (e) {
      debugPrint("Font load failed, using standard fonts: $e");
      englishFont = pw.Font.helvetica();
      englishBold = pw.Font.helveticaBold();
      hindiFont = pw.Font.helvetica();
      hindiBold = pw.Font.helveticaBold();
    }

    final receiptNo = 'CILCASH${DateTime.now().millisecondsSinceEpoch}';
    final receiptDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    final dated = DateFormat('dd/MM/yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: englishFont,
          bold: englishBold,
          fontFallback: hindiFont != null ? [hindiFont, hindiBold ?? hindiFont] : [],
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'SETIA AUTO FINANCE (P) LTD.',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#C62828'),
                      ),
                    ),
                    pw.Text(
                      'Receipt Details',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 25),

              // Info Section using Table for better constraint handling
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Table(
                      columnWidths: {
                        0: const pw.FixedColumnWidth(80),
                        1: const pw.FixedColumnWidth(10),
                        2: const pw.FlexColumnWidth(),
                      },
                      children: [
                        _infoTableRow('Branch', item.city.isEmpty ? 'Jaipur' : item.city),
                        _infoTableRow('Account No.', item.loanNo),
                        _infoTableRow('Received From', item.customer),
                        _infoTableRow('Reason', remark.isEmpty ? 'EMI / Part Payment' : remark),
                        _infoTableRow('Cheque/DD no.', ''),
                        _infoTableRow('Drawn on', ''),
                        _infoTableRow('Emp Code', 'CLL001'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Table(
                      columnWidths: {
                        0: const pw.FixedColumnWidth(90),
                        1: const pw.FixedColumnWidth(10),
                        2: const pw.FlexColumnWidth(),
                      },
                      children: [
                        _infoTableRow('Receipt-Number', receiptNo),
                        _infoTableRow('Receipt-Date', receiptDate),
                        _infoTableRow('Sum of Rupees', amount.toStringAsFixed(2)),
                        _infoTableRow('Payment Mode', 'Cash'),
                        _infoTableRow('Dated', dated),
                        _infoTableRow('Emp Name', 'Admin'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 25),

              pw.Text('Transaction ID:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFCDD2)),
                    children: [
                      _tableCell('Towards', bold: true),
                      _tableCell('EMI/Deliverables/Foreclosure/Part Payment', bold: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableCell('Installment Amount'),
                      _tableCell(amount.toStringAsFixed(2)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableCell('Total Penalty Charges'),
                      _tableCell('0.00'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableCell('Cash Handling Charges'),
                      _tableCell('0.00'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableCell('Total', bold: true),
                      _tableCell(amount.toStringAsFixed(2), bold: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableCell('Total Amount(In Words)', bold: true),
                      _tableCell('${_amountInWords(amount.toInt())} Rupees Only', bold: true),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 25),

              // Terms & Conditions
              pw.Text('नियम एवं शर्तें (Terms & Conditions):',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.SizedBox(height: 8),
              _term('1. सभी कैश/डी.डी भुगतान उनकी प्राप्ति के अधीन होंगे।'),
              _term('2. भुगतान करने के पश्चात कृपया रसीद अवश्य प्राप्त करें।'),
              _term('3. ग्राहक अपने मोबाइल के माध्यम से Google Pay, PhonePe एवं Paytm से भुगतान कर सकते हैं।'),
              _term('4. रसीद स्वीकार करने से पूर्व कृपया अपने लोन विवरण की जांच कर लें।'),

              pw.SizedBox(height: 30),

              // Footer
              pw.Text(
                'Corporate Office: K-13, 5th Floor, Brij Anukampa Tower, Ashok Marg, C-Scheme, Jaipur, Rajasthan 302001.',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.Text('Help Line Number : 7727091111',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('Email: care@setiafinance.com',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('Website: https://www.setiafinance.com',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.TableRow _infoTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(':', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _term(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  static String _amountInWords(int amount) {
    if (amount == 0) return 'Zero';
    final ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    String convert(int n) {
      if (n < 20) return ones[n];
      if (n < 100) return '${tens[n ~/ 10]} ${ones[n % 10]}'.trim();
      if (n < 1000) return '${ones[n ~/ 100]} Hundred ${convert(n % 100)}'.trim();
      if (n < 100000) return '${convert(n ~/ 1000)} Thousand ${convert(n % 1000)}'.trim();
      return '${convert(n ~/ 100000)} Lakh ${convert(n % 100000)}'.trim();
    }
    return convert(amount);
  }
}
