import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/customer_case.dart';

class AnalyticsReportService {
  static Future<void> generateAndDownloadReport({
    required List<CustomerCase> cases,
    required double totalDistance,
    required String totalDuration,
  }) async {
    final pdf = pw.Document();
    
    final englishFont = await PdfGoogleFonts.robotoRegular();
    final englishBold = await PdfGoogleFonts.robotoBold();

    final double totalDue = cases.fold(0, (p, e) => p + e.dueAmount);
    final double collected = cases.fold(0, (p, e) => p + e.collectedAmount);
    final int visitedCount = cases.where((e) => ['Visited', 'Collected', 'PTP', 'Part Payment'].contains(e.status)).length;
    final int ptpCount = cases.where((e) => e.status == 'PTP').length;
    final int pendingCount = cases.where((e) => e.status == 'Pending').length;
    final int collectedCount = cases.where((e) => e.status == 'Collected').length;

    Map<String, int> categoryCount = {};
    for (var c in cases) {
      categoryCount[c.type] = (categoryCount[c.type] ?? 0) + 1;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: englishFont, bold: englishBold),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SAFL Performance Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            pw.Text('Performance Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                _tableRow(['Metric', 'Value'], isHeader: true),
                _tableRow(['Total Cases', '${cases.length}']),
                _tableRow(['Total Portfolio', 'INR ${totalDue.toStringAsFixed(2)}']),
                _tableRow(['Total Collected', 'INR ${collected.toStringAsFixed(2)}']),
                _tableRow(['Collection Efficiency', '${cases.isEmpty ? 0 : (visitedCount / cases.length * 100).toStringAsFixed(1)}%']),
                _tableRow(['Pending Outstanding', 'INR ${(totalDue - collected).toStringAsFixed(2)}']),
              ],
            ),

            pw.SizedBox(height: 30),
            pw.Text('Collection Status Breakdown', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                _tableRow(['Status', 'Count'], isHeader: true),
                _tableRow(['Pending', '$pendingCount']),
                _tableRow(['Visited', '$visitedCount']),
                _tableRow(['PTP (Promise to Pay)', '$ptpCount']),
                _tableRow(['Fully Collected', '$collectedCount']),
              ],
            ),

            pw.SizedBox(height: 30),
            pw.Text('Category Wise Allocation', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                _tableRow(['Category', 'Cases'], isHeader: true),
                ...categoryCount.entries.map((e) => _tableRow([e.key, '${e.value}'])),
              ],
            ),

            pw.SizedBox(height: 30),
            pw.Text('Field Visit Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Bullet(text: 'Total Distance Covered: ${totalDistance.toStringAsFixed(2)} KM'),
            pw.Bullet(text: 'Total Field Time: $totalDuration'),
            pw.Bullet(text: 'Travel Allowance (at 2.5/KM): INR ${(totalDistance * 2.5).toStringAsFixed(2)}'),

            pw.Footer(
              margin: const pw.EdgeInsets.only(top: 40),
              trailing: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'SAFL_Analytics_Report_${DateFormat('ddMMyy').format(DateTime.now())}.pdf',
    );
  }

  static pw.TableRow _tableRow(List<String> cells, {bool isHeader = false}) {
    return pw.TableRow(
      children: cells.map((cell) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          cell,
          style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      )).toList(),
    );
  }
}
