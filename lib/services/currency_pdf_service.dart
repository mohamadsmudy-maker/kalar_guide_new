import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'currency_service.dart';

/// 📄 ڕاپۆرتی PDF بۆ دراو
class CurrencyPdfService {
  // ═══════════════════════════════════════════════════════════
  // 📄 ڕاپۆرتی دراوێک — Single Report
  // ═══════════════════════════════════════════════════════════
  static Future<void> generateSingleReport({
    required BuildContext context,
    required String currencyName,
    required String currencyCode,
    required List<Map<String, dynamic>> history,
  }) async {
    try {
      if (history.isEmpty) {
        _showMessage(context, 'هیچ داتایەک نییە');
        return;
      }

      final pdf = pw.Document();
      final font = await PdfGoogleFonts.notoNaskhArabicRegular();
      final fontBold = await PdfGoogleFonts.notoNaskhArabicBold();

      final sorted = List<Map<String, dynamic>>.from(history)
        ..sort((a, b) {
          final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '');
          final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '');
          if (dateA == null || dateB == null) return 0;
          return dateA.compareTo(dateB);
        });

      final firstBuy =
          (sorted.first['new_buy_price'] as num?)?.toDouble() ?? 0;
      final lastBuy =
          (sorted.last['new_buy_price'] as num?)?.toDouble() ?? 0;
      final firstSell =
          (sorted.first['new_sell_price'] as num?)?.toDouble() ?? 0;
      final lastSell =
          (sorted.last['new_sell_price'] as num?)?.toDouble() ?? 0;
      final diffBuy = lastBuy - firstBuy;
      final diffSell = lastSell - firstSell;

      final allBuys = sorted
          .map((h) => (h['new_buy_price'] as num?)?.toDouble() ?? 0)
          .toList();
      final allSells = sorted
          .map((h) => (h['new_sell_price'] as num?)?.toDouble() ?? 0)
          .toList();

      final minBuy = allBuys.reduce((a, b) => a < b ? a : b);
      final maxBuy = allBuys.reduce((a, b) => a > b ? a : b);
      final minSell = allSells.reduce((a, b) => a < b ? a : b);
      final maxSell = allSells.reduce((a, b) => a > b ? a : b);

      pdf.addPage(
        pw.MultiPage(
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ڕاپۆرتی مێژووی نرخی $currencyName',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Divider(color: PdfColors.grey400),
              ],
            ),
          ),
          build: (context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'کۆد: $currencyCode',
                  style: pw.TextStyle(font: fontBold, fontSize: 11),
                ),
                pw.Text(
                  'کۆی گۆڕانکارییەکان: ${sorted.length}',
                  style: pw.TextStyle(font: fontBold, fontSize: 11),
                ),
                pw.Text(
                  'بەروار: ${DateTime.now().toString().substring(0, 10)}',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            _buildStatsSection(
              firstBuy: firstBuy,
              lastBuy: lastBuy,
              diffBuy: diffBuy,
              minBuy: minBuy,
              maxBuy: maxBuy,
              firstSell: firstSell,
              lastSell: lastSell,
              diffSell: diffSell,
              minSell: minSell,
              maxSell: maxSell,
              font: font,
              fontBold: fontBold,
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              '📋 لیستی گۆڕانکارییەکان',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 13,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [
                '#',
                'بەروار',
                'کڕین (کۆن → نوێ)',
                'فرۆشتن (کۆن → نوێ)',
                'لەلایەن',
              ],
              data: sorted.reversed.toList().asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                final oldBuy = (item['old_buy_price'] as num?)?.toDouble();
                final newBuy =
                    (item['new_buy_price'] as num?)?.toDouble() ?? 0;
                final oldSell = (item['old_sell_price'] as num?)?.toDouble();
                final newSell =
                    (item['new_sell_price'] as num?)?.toDouble() ?? 0;
                final updatedBy =
                    item['updated_by_name']?.toString() ?? '-';
                final createdAt = item['created_at'] != null
                    ? DateTime.tryParse(item['created_at'].toString())
                    : null;

                String dateStr = '';
                if (createdAt != null) {
                  dateStr =
                  '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}';
                }

                return [
                  idx.toString(),
                  dateStr,
                  '${oldBuy?.toStringAsFixed(0) ?? "-"} → ${newBuy.toStringAsFixed(0)}',
                  '${oldSell?.toStringAsFixed(0) ?? "-"} → ${newSell.toStringAsFixed(0)}',
                  updatedBy,
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(
                font: fontBold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.indigo900,
              ),
              cellAlignment: pw.Alignment.centerRight,
              cellStyle: pw.TextStyle(font: font, fontSize: 9),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'ئەم ڕاپۆرتە لەلایەن ئەپی ڕێبەری کەلار بەرهەم هاتووە',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name:
        'currency_${currencyCode}_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      _showMessage(context, 'هەڵە لە دروستکردنی PDF: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 ڕاپۆرتی هەموو دراوەکان — Multi Report
  // ═══════════════════════════════════════════════════════════
  static Future<void> generateMultiReport({
    required BuildContext context,
    required List<Map<String, dynamic>> allHistory,
  }) async {
    try {
      if (allHistory.isEmpty) {
        _showMessage(context, 'هیچ داتایەک نییە');
        return;
      }

      final pdf = pw.Document();
      final font = await PdfGoogleFonts.notoNaskhArabicRegular();
      final fontBold = await PdfGoogleFonts.notoNaskhArabicBold();

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      final Map<String, String> names = {};

      for (final item in allHistory) {
        final code = item['currency_type']?.toString() ?? '';
        if (code.isEmpty) continue;
        grouped.putIfAbsent(code, () => []).add(item);
        names[code] = CurrencyService.getNameKu(code);
      }

      final sortedCodes = grouped.keys.toList()..sort();

      pdf.addPage(
        pw.MultiPage(
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ڕاپۆرتی گشتی نرخی دراوەکان',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Divider(color: PdfColors.grey400),
              ],
            ),
          ),
          build: (context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'کۆی دراوەکان: ${sortedCodes.length}',
                  style: pw.TextStyle(font: fontBold, fontSize: 11),
                ),
                pw.Text(
                  'کۆی گۆڕانکارییەکان: ${allHistory.length}',
                  style: pw.TextStyle(font: fontBold, fontSize: 11),
                ),
                pw.Text(
                  'بەروار: ${DateTime.now().toString().substring(0, 10)}',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            ...sortedCodes.expand((code) {
              final items = grouped[code]!;

              items.sort((a, b) {
                final dateA =
                DateTime.tryParse(a['created_at']?.toString() ?? '');
                final dateB =
                DateTime.tryParse(b['created_at']?.toString() ?? '');
                if (dateA == null || dateB == null) return 0;
                return dateA.compareTo(dateB);
              });

              final firstBuy =
                  (items.first['new_buy_price'] as num?)?.toDouble() ?? 0;
              final lastBuy =
                  (items.last['new_buy_price'] as num?)?.toDouble() ?? 0;
              final diffBuy = lastBuy - firstBuy;
              final name = names[code] ?? code;

              return [
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 16, bottom: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo50,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '$name ($code)',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 12,
                          color: PdfColors.indigo900,
                        ),
                      ),
                      pw.Row(
                        children: [
                          pw.Text(
                            'نرخی ئێستا: ${lastBuy.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            '${diffBuy >= 0 ? "+" : ""}${diffBuy.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: diffBuy > 0
                                  ? PdfColors.red
                                  : (diffBuy < 0
                                  ? PdfColors.green
                                  : PdfColors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.TableHelper.fromTextArray(
                  headers: [
                    '#',
                    'بەروار',
                    'کڕین',
                    'فرۆشتن',
                    'لەلایەن',
                  ],
                  data: items.reversed.toList().asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    final newBuy =
                        (item['new_buy_price'] as num?)?.toDouble() ?? 0;
                    final newSell =
                        (item['new_sell_price'] as num?)?.toDouble() ?? 0;
                    final updatedBy =
                        item['updated_by_name']?.toString() ?? '-';
                    final createdAt = item['created_at'] != null
                        ? DateTime.tryParse(item['created_at'].toString())
                        : null;

                    String dateStr = '';
                    if (createdAt != null) {
                      dateStr =
                      '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}';
                    }

                    return [
                      idx.toString(),
                      dateStr,
                      newBuy.toStringAsFixed(0),
                      newSell.toStringAsFixed(0),
                      updatedBy,
                    ];
                  }).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(
                    font: fontBold,
                    color: PdfColors.white,
                    fontSize: 9,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.indigo900,
                  ),
                  cellAlignment: pw.Alignment.centerRight,
                  cellStyle: pw.TextStyle(font: font, fontSize: 8),
                  oddRowDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                  ),
                ),
              ];
            }),
            pw.SizedBox(height: 20),
            pw.Text(
              'ئەم ڕاپۆرتە لەلایەن ئەپی ڕێبەری کەلار بەرهەم هاتووە',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name:
        'currency_multi_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      _showMessage(context, 'هەڵە لە دروستکردنی PDF: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ Helpers
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildStatsSection({
    required double firstBuy,
    required double lastBuy,
    required double diffBuy,
    required double minBuy,
    required double maxBuy,
    required double firstSell,
    required double lastSell,
    required double diffSell,
    required double minSell,
    required double maxSell,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            '📊 ئاماری کورت',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 12,
              color: PdfColors.indigo900,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _statBox(
                'نرخی یەکەم (کڕین)',
                firstBuy.toStringAsFixed(0),
                font,
                fontBold,
              ),
              _statBox(
                'نرخی کۆتایی (کڕین)',
                lastBuy.toStringAsFixed(0),
                font,
                fontBold,
              ),
              _statBox(
                'گۆڕانکاری (کڕین)',
                '${diffBuy >= 0 ? "+" : ""}${diffBuy.toStringAsFixed(0)}',
                font,
                fontBold,
                color: diffBuy > 0
                    ? PdfColors.red
                    : (diffBuy < 0 ? PdfColors.green : PdfColors.grey),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _statBox(
                'نزمترین (کڕین)',
                minBuy.toStringAsFixed(0),
                font,
                fontBold,
              ),
              _statBox(
                'بەرزترین (کڕین)',
                maxBuy.toStringAsFixed(0),
                font,
                fontBold,
              ),
              _statBox(
                'گۆڕانکاری (فرۆشتن)',
                '${diffSell >= 0 ? "+" : ""}${diffSell.toStringAsFixed(0)}',
                font,
                fontBold,
                color: diffSell > 0
                    ? PdfColors.red
                    : (diffSell < 0 ? PdfColors.green : PdfColors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _statBox(
      String label,
      String value,
      pw.Font font,
      pw.Font fontBold, {
        PdfColor? color,
      }) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 14,
            color: color ?? PdfColors.indigo900,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            color: PdfColors.grey700,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  static void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}