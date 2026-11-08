// lib/services/fuel_pdf_service.dart
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'fuel_service.dart';

/// 📄 ڕاپۆرتی PDF ی پرۆفیشناڵ بۆ سووتەمەنی — Ultra Pro Max
class FuelPdfService {
  // 🎨 ڕەنگەکان
  static const PdfColor _primaryDark = PdfColor.fromInt(0xFF1A1B2E);
  static const PdfColor _primaryGold = PdfColor.fromInt(0xFFFFD700);
  static const PdfColor _primaryBlue = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor _successGreen = PdfColor.fromInt(0xFF10B981);
  static const PdfColor _dangerRed = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor _grey = PdfColors.grey600;
  static const PdfColor _lightGrey = PdfColors.grey100;

  static const PdfColor _white70 = PdfColor.fromInt(0xB3FFFFFF);
  static const PdfColor _white60 = PdfColor.fromInt(0x99FFFFFF);
  static const PdfColor _white10 = PdfColor.fromInt(0x1AFFFFFF);

  // ═══════════════════════════════════════════════════════════
  // 📄 دروستکردنی ڕاپۆرت
  // ═══════════════════════════════════════════════════════════
  static Future<void> generateDateRangeReport({
    required BuildContext context,
    required DateTime fromDate,
    required DateTime toDate,
    String? fuelType,
  }) async {
    try {
      final history = await FuelService.getMonthlyHistory(monthsBack: 12);

      final filtered = history.where((item) {
        final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
        if (createdAt == null) return false;
        final isInRange = createdAt.isAfter(fromDate.subtract(const Duration(days: 1))) &&
            createdAt.isBefore(toDate.add(const Duration(days: 1)));
        if (fuelType != null && fuelType.isNotEmpty) {
          return isInRange && item['fuel_type'] == fuelType;
        }
        return isInRange;
      }).toList();

      if (filtered.isEmpty) {
        if (context.mounted) _showMessage(context, 'هیچ داتایەک نییە بۆ ئەم ماوەیە');
        return;
      }

      filtered.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      final pdf = pw.Document();
      final font = await PdfGoogleFonts.notoNaskhArabicRegular();
      final fontBold = await PdfGoogleFonts.notoNaskhArabicBold();

      final prices = filtered.map((h) => (h['new_price'] as num?)?.toDouble() ?? 0).toList();
      final minPrice = prices.reduce((a, b) => a < b ? a : b);
      final maxPrice = prices.reduce((a, b) => a > b ? a : b);
      final avgPrice = prices.reduce((a, b) => a + b) / prices.length;
      final firstPrice = prices.first;
      final lastPrice = prices.last;
      final diff = lastPrice - firstPrice;
      final percentChange = firstPrice > 0 ? (diff / firstPrice) * 100 : 0.0;

      final groupedByType = <String, List<Map<String, dynamic>>>{};
      for (final item in filtered) {
        final type = item['fuel_type']?.toString() ?? '';
        groupedByType.putIfAbsent(type, () => []).add(item);
      }

      final groupedByDate = <String, List<Map<String, dynamic>>>{};
      for (final item in filtered) {
        final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
        if (createdAt == null) continue;
        final key = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        groupedByDate.putIfAbsent(key, () => []).add(item);
      }

      pdf.addPage(
        pw.MultiPage(
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (ctx) => _buildHeader(
            font: font,
            fontBold: fontBold,
            fromDate: fromDate,
            toDate: toDate,
            fuelType: fuelType,
          ),
          footer: (ctx) => _buildFooter(font: font, fontBold: fontBold, context: ctx),
          build: (ctx) => [
            _buildReportInfo(
              font: font,
              fontBold: fontBold,
              totalRecords: filtered.length,
              totalTypes: groupedByType.length,
              totalDays: groupedByDate.length,
            ),
            pw.SizedBox(height: 16),
            _buildStatsSection(
              font: font,
              fontBold: fontBold,
              minPrice: minPrice,
              maxPrice: maxPrice,
              avgPrice: avgPrice,
              firstPrice: firstPrice,
              lastPrice: lastPrice,
              diff: diff,
              percentChange: percentChange,
            ),
            pw.SizedBox(height: 20),
            _buildChartSection(
              font: font,
              fontBold: fontBold,
              history: filtered,
              color: PdfColor.fromHex(FuelService.getColorForType(fuelType ?? 'normal').replaceAll('#', '')),
            ),
            pw.SizedBox(height: 20),
            pw.Text('📊 ئامار بەپێی جۆر', style: pw.TextStyle(font: fontBold, fontSize: 14, color: _primaryDark)),
            pw.SizedBox(height: 10),
            _buildTypesSummary(font: font, fontBold: fontBold, groupedByType: groupedByType),
            pw.SizedBox(height: 20),
            pw.Text('📋 لیستی گۆڕانکارییەکان', style: pw.TextStyle(font: fontBold, fontSize: 14, color: _primaryDark)),
            pw.SizedBox(height: 10),
            _buildDataTable(font: font, fontBold: fontBold, filtered: filtered),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'fuel_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('❌ هەڵە لە دروستکردنی PDF: $e');
      if (context.mounted) _showMessage(context, 'هەڵە لە دروستکردنی PDF: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 یاریدەدەرەکانی PDF (Header, Footer, ...)
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildHeader({
    required pw.Font font,
    required pw.Font fontBold,
    required DateTime fromDate,
    required DateTime toDate,
    String? fuelType,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(colors: [_primaryDark, PdfColor.fromInt(0xFF2D1B4E)]),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 50,
            height: 50,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(colors: [_primaryGold, PdfColor.fromInt(0xFFFFB300)]),
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(child: pw.Text('⛽', style: const pw.TextStyle(fontSize: 24))),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ڕاپۆرتی نرخی سووتەمەنی', style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text(fuelType != null ? 'جۆری: ${FuelService.getNameKu(fuelType)}' : 'هەموو جۆرەکان', style: pw.TextStyle(font: font, fontSize: 11, color: _white70)),
                pw.SizedBox(height: 2),
                pw.Text('لە ${_formatDate(fromDate)} بۆ ${_formatDate(toDate)}', style: pw.TextStyle(font: font, fontSize: 10, color: _white60)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(color: _white10, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
              children: [
                pw.Text('بەروار', style: pw.TextStyle(font: font, fontSize: 8, color: _white60)),
                pw.SizedBox(height: 2),
                pw.Text(DateTime.now().toString().substring(0, 10), style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter({required pw.Font font, required pw.Font fontBold, required pw.Context context}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: _lightGrey, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('🏙️ ڕێبەری کەلار — ئەپی فەرمی شاری کەلار', style: pw.TextStyle(font: fontBold, fontSize: 9, color: _primaryDark)),
          pw.Text('لاپەڕە ${context.pageNumber} لە ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: _grey)),
        ],
      ),
    );
  }

  static pw.Widget _buildReportInfo({required pw.Font font, required pw.Font fontBold, required int totalRecords, required int totalTypes, required int totalDays}) {
    return pw.Row(
      children: [
        _buildInfoBox(icon: '📋', label: 'کۆی تۆمارەکان', value: '$totalRecords', color: _primaryBlue, font: font, fontBold: fontBold),
        pw.SizedBox(width: 8),
        _buildInfoBox(icon: '🛢️', label: 'جۆرەکان', value: '$totalTypes', color: _successGreen, font: font, fontBold: fontBold),
        pw.SizedBox(width: 8),
        _buildInfoBox(icon: '📅', label: 'ڕۆژەکان', value: '$totalDays', color: const PdfColor.fromInt(0xFFF59E0B), font: font, fontBold: fontBold),
      ],
    );
  }

  static pw.Widget _buildInfoBox({required String icon, required String label, required String value, required PdfColor color, required pw.Font font, required pw.Font fontBold}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Column(
          children: [
            pw.Text(icon, style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9, color: _white70)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildStatsSection({required pw.Font font, required pw.Font fontBold, required double minPrice, required double maxPrice, required double avgPrice, required double firstPrice, required double lastPrice, required double diff, required double percentChange}) {
    final isUp = diff > 0;
    final isDown = diff < 0;
    final changeColor = isUp ? _dangerRed : isDown ? _successGreen : _grey;

    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(color: _lightGrey, borderRadius: pw.BorderRadius.circular(12), border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('📊 ئاماری کورت', style: pw.TextStyle(font: fontBold, fontSize: 13, color: _primaryDark)),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  _buildStatBox(icon: '⬇️', label: 'نزمترین', value: minPrice.toStringAsFixed(0), color: _successGreen, font: font, fontBold: fontBold),
                  pw.SizedBox(width: 8),
                  _buildStatBox(icon: '📊', label: 'تێکڕا', value: avgPrice.toStringAsFixed(0), color: _primaryBlue, font: font, fontBold: fontBold),
                  pw.SizedBox(width: 8),
                  _buildStatBox(icon: '⬆️', label: 'بەرزترین', value: maxPrice.toStringAsFixed(0), color: _dangerRed, font: font, fontBold: fontBold),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(color: changeColor, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Row(
                  children: [
                    pw.Text(isUp ? '📈' : isDown ? '📉' : '➖', style: const pw.TextStyle(fontSize: 16)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(isUp ? 'زیادبوونی گشتی' : isDown ? 'کەمبوونەوەی گشتی' : 'بێ گۆڕانکاری', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.white)),
                    ),
                    pw.Text('${isUp ? "+" : ""}${diff.toStringAsFixed(0)} د.ع', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.white)),
                    pw.SizedBox(width: 6),
                    pw.Text('(${percentChange.toStringAsFixed(1)}%)', style: pw.TextStyle(font: font, fontSize: 10, color: _white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildStatBox({required String icon, required String label, required String value, required PdfColor color, required pw.Font font, required pw.Font fontBold}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: color, width: 1.5)),
        child: pw.Column(
          children: [
            pw.Text(icon, style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 16, color: color)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8, color: _grey)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildChartSection({required pw.Font font, required pw.Font fontBold, required List<Map<String, dynamic>> history, required PdfColor color}) {
    if (history.length < 2) return pw.SizedBox.shrink();

    final prices = history.map((h) => (h['new_price'] as num?)?.toDouble() ?? 0).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final range = maxPrice - minPrice;

    final step = (history.length / 20).ceil().clamp(1, 100);
    final displayPoints = <int>[];
    for (int i = 0; i < history.length; i += step) {
      displayPoints.add(i);
    }
    if (displayPoints.last != history.length - 1) {
      displayPoints.add(history.length - 1);
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(12), border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('📈 چارتی گۆڕانکاری', style: pw.TextStyle(font: fontBold, fontSize: 13, color: _primaryDark)),
              pw.Spacer(),
              pw.Text('${history.length} خاڵ', style: pw.TextStyle(font: font, fontSize: 9, color: _grey)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.SizedBox(
            height: 140,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: displayPoints.map((i) {
                final price = prices[i];
                final height = range > 0 ? ((price - minPrice) / range) * 100 + 20 : 50.0;
                final date = DateTime.tryParse(history[i]['created_at']?.toString() ?? '');

                return pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 1),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Container(
                          height: height,
                          decoration: pw.BoxDecoration(
                            gradient: pw.LinearGradient(colors: [color, PdfColors.white], begin: pw.Alignment.topCenter, end: pw.Alignment.bottomCenter),
                            borderRadius: const pw.BorderRadius.only(topLeft: pw.Radius.circular(3), topRight: pw.Radius.circular(3)),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(date != null ? '${date.day}/${date.month}' : '', style: pw.TextStyle(font: font, fontSize: 5, color: _grey)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(2))),
              pw.SizedBox(width: 4),
              pw.Text('نرخی سووتەمەنی', style: pw.TextStyle(font: font, fontSize: 8, color: _grey)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTypesSummary({required pw.Font font, required pw.Font fontBold, required Map<String, List<Map<String, dynamic>>> groupedByType}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _lightGrey, borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Column(
        children: groupedByType.entries.map((entry) {
          final type = entry.key;
          final items = entry.value;
          final prices = items.map((h) => (h['new_price'] as num?)?.toDouble() ?? 0).toList();
          final minP = prices.reduce((a, b) => a < b ? a : b);
          final maxP = prices.reduce((a, b) => a > b ? a : b);
          final color = PdfColor.fromHex(FuelService.getColorForType(type).replaceAll('#', ''));

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              children: [
                pw.Container(width: 12, height: 12, decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3))),
                pw.SizedBox(width: 8),
                pw.Expanded(child: pw.Text(FuelService.getNameKu(type), style: pw.TextStyle(font: fontBold, fontSize: 10, color: _primaryDark))),
                pw.Text('${items.length} تۆمار', style: pw.TextStyle(font: font, fontSize: 9, color: _grey)),
                pw.SizedBox(width: 12),
                pw.Text('${minP.toStringAsFixed(0)} — ${maxP.toStringAsFixed(0)} د.ع', style: pw.TextStyle(font: fontBold, fontSize: 9, color: _primaryDark)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildDataTable({required pw.Font font, required pw.Font fontBold, required List<Map<String, dynamic>> filtered}) {
    return pw.TableHelper.fromTextArray(
      headers: ['#', 'بەروار', 'کات', 'جۆر', 'نرخی کۆن', 'نرخی نوێ', 'گۆڕانکاری', 'لەلایەن'],
      data: filtered.reversed.toList().asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final item = entry.value;
        final fuelType = item['fuel_type']?.toString() ?? '';
        final oldPrice = (item['old_price'] as num?)?.toDouble();
        final newPrice = (item['new_price'] as num?)?.toDouble() ?? 0;
        final updatedBy = item['updated_by_name']?.toString() ?? '-';
        final createdAt = item['created_at'] != null ? DateTime.tryParse(item['created_at'].toString()) : null;

        final diff = oldPrice != null ? newPrice - oldPrice : 0;
        final diffText = oldPrice == null ? '-' : '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(0)}';

        return [
          idx.toString(),
          createdAt != null ? '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}' : '-',
          createdAt != null ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}' : '-',
          FuelService.getNameKu(fuelType),
          oldPrice?.toStringAsFixed(0) ?? '-',
          newPrice.toStringAsFixed(0),
          diffText,
          updatedBy,
        ];
      }).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: _primaryDark),
      cellAlignment: pw.Alignment.centerRight,
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      cellPadding: const pw.EdgeInsets.all(5),
      oddRowDecoration: const pw.BoxDecoration(color: _lightGrey),
      headerAlignment: pw.Alignment.centerRight,
    );
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  static void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}