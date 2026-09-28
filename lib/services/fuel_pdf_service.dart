import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/fuel_price_history.dart';
import 'fuel_service.dart';

/// 📄 ڕاپۆرتی PDF بۆ سووتەمەنی
class FuelPdfService {
  static Future<void> generateMonthlyReport({
    required BuildContext context,
    required String fuelTypeName,
    int monthsBack = 3,
  }) async {
    try {
      final history = await FuelService.getMonthlyHistory(monthsBack: monthsBack);

      if (history.isEmpty) {
        _showMessage(context, 'هیچ داتایەک نییە');
        return;
      }

      final pdf = pw.Document();

      final grouped = <String, List<FuelPriceHistory>>{};
      for (final item in history) {
        if (item.createdAt == null) continue;
        final key =
            '${item.createdAt!.year}-${item.createdAt!.month.toString().padLeft(2, '0')}';
        grouped.putIfAbsent(key, () => []).add(item);
      }

      final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [
                    PdfColor.fromInt(0xFF1E88E5),
                    PdfColor.fromInt(0xFF64B5F6),
                  ],
                ),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ڕاپۆرتی نرخی سووتەمەنی',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'جۆری سووتەمەنی: $fuelTypeName',
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'بەروار: ${_formatDate(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _statBox('کۆی تۆمارەکان', '${history.length}'),
                  _statBox(
                    'ژمارەی بەنزینخانەکان',
                    '${history.map((e) => e.stationId).toSet().length}',
                  ),
                  _statBox('ماوە', '$monthsBack مانگ'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            ...sortedKeys.expand((monthKey) {
              final items = grouped[monthKey]!;
              final sortedItems = [...items]
                ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

              return [
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 16, bottom: 8),
                  child: pw.Text(
                    _formatMonth(monthKey),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF1E88E5),
                    ),
                  ),
                ),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF1E88E5),
                      ),
                      children: [
                        _headerCell('بەنزینخانە'),
                        _headerCell('نرخ (د.ع)'),
                        _headerCell('یەکە'),
                        _headerCell('کات'),
                        _headerCell('لەلایەن'),
                      ],
                    ),
                    ...sortedItems.take(20).map((item) => pw.TableRow(
                      children: [
                        _bodyCell(item.stationNameKu ?? ''),
                        _bodyCell('${item.price.toStringAsFixed(0)} د.ع'),
                        _bodyCell(item.unit),
                        _bodyCell(_formatDateTime(item.createdAt!)),
                        _bodyCell(item.updatedByName ?? '-'),
                      ],
                    )),
                  ],
                ),
              ];
            }),
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.Text(
              'ئەم ڕاپۆرتە لەلایەن ئەپی ڕێبەری کەلار بەرهەم هاتووە',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'fuel_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      _showMessage(context, 'هەڵە لە دروستکردنی PDF: $e');
    }
  }

  static pw.Widget _statBox(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF1E88E5),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _bodyCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime d) {
    return '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _formatMonth(String key) {
    final parts = key.split('-');
    const months = [
      'کانوونی دووەم',
      'شوبات',
      'ئازار',
      'نیسان',
      'ئایار',
      'حوزەیران',
      'تەممووز',
      'ئاب',
      'ئەیلوول',
      'تشرینی یەکەم',
      'تشرینی دووەم',
      'کانوونی یەکەم'
    ];
    final month = int.tryParse(parts[1]) ?? 1;
    return '${months[month - 1]} ${parts[0]}';
  }

  static void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}