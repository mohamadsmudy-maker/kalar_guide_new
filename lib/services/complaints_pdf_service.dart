import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'ai_service.dart';

/// 📄 ڕاپۆرتی PDF ی پرۆفیشناڵ بۆ سکاڵاکان
class ComplaintsPdfService {
  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕەنگەکان — PDF compatible
  // ═══════════════════════════════════════════════════════════
  static const PdfColor _primaryDark = PdfColor.fromInt(0xFF1A1B2E);
  static const PdfColor _primaryPink = PdfColor.fromInt(0xFFE91E63);
  static const PdfColor _primaryBlue = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor _successGreen = PdfColor.fromInt(0xFF10B981);
  static const PdfColor _dangerRed = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor _warningOrange = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor _grey = PdfColors.grey600;
  static const PdfColor _lightGrey = PdfColors.grey100;

  // ✅ ڕەنگی سپی بە شەفافیەتی جیاواز
  static const PdfColor _white70 = PdfColor.fromInt(0xB3FFFFFF);
  static const PdfColor _white60 = PdfColor.fromInt(0x99FFFFFF);

  static const PdfColor _white20 = PdfColor.fromInt(0x33FFFFFF);
  static const PdfColor _white10 = PdfColor.fromInt(0x1AFFFFFF);

  // ═══════════════════════════════════════════════════════════
  // 📄 ڕاپۆرتی PDF — پرۆفیشناڵ
  // ═══════════════════════════════════════════════════════════
  static Future<void> generateReport({
    required BuildContext context,
    required List<Map<String, dynamic>> complaints,
    DateTime? fromDate,
    DateTime? toDate,
    String? statusFilter,
  }) async {
    try {
      List<Map<String, dynamic>> filtered = complaints;
      if (fromDate != null && toDate != null) {
        filtered = complaints.where((item) {
          final createdAt = DateTime.tryParse(
            item['created_at']?.toString() ?? '',
          );
          if (createdAt == null) return false;
          return createdAt.isAfter(
            fromDate.subtract(const Duration(days: 1)),
          ) &&
              createdAt.isBefore(toDate.add(const Duration(days: 1)));
        }).toList();
      }

      if (filtered.isEmpty) {
        _showMessage(context, 'هیچ سکاڵایەک نییە بۆ ئەم ماوەیە');
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

      // ✅ ئامارەکان
      final statusCount = <String, int>{};
      for (final c in filtered) {
        final status = c['status']?.toString() ?? 'pending';
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }

      final categoryCount = <String, int>{};
      for (final c in filtered) {
        final cat = c['title']?.toString() ?? 'نەناسراو';
        categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
      }

      final authorityCount = <String, int>{};
      for (final c in filtered) {
        final auth =
            c['responsible_authority']?.toString() ?? 'نەناسراو';
        authorityCount[auth] = (authorityCount[auth] ?? 0) + 1;
      }

      // ✅ ئاماری AI
      String aiAnalysis = 'شیکردنەوە بەردەست نییە';
      try {
        final summary = filtered
            .take(20)
            .map((c) => "${c['title']}: ${c['status']}")
            .join('\n');
        aiAnalysis = await AiService.askAdminAI(
          "ئەم کورتەیەی سکاڵاکان شیکار بکە و تەنها ٣ خاڵی گرنگ بە کوردی سۆرانی بنووسە:",
          summary,
        );
      } catch (_) {}

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
          ),
          footer: (ctx) => _buildFooter(
            font: font,
            fontBold: fontBold,
            context: ctx,
          ),
          build: (ctx) => [
            // ═══ زانیاری ڕاپۆرت ═══
            _buildReportInfo(
              font: font,
              fontBold: fontBold,
              totalComplaints: filtered.length,
              totalStatus: statusCount.length,
              totalCategories: categoryCount.length,
              totalAuthorities: authorityCount.length,
            ),
            pw.SizedBox(height: 16),

            // ═══ ئاماری دۆخ ═══
            _buildStatusStats(
              font: font,
              fontBold: fontBold,
              statusCount: statusCount,
              total: filtered.length,
            ),
            pw.SizedBox(height: 20),

            // ═══ Chart — Status ═══
            _buildStatusChart(
              font: font,
              fontBold: fontBold,
              statusCount: statusCount,
              total: filtered.length,
            ),
            pw.SizedBox(height: 20),

            // ═══ Chart — Category ═══
            _buildCategoryChart(
              font: font,
              fontBold: fontBold,
              categoryCount: categoryCount,
            ),
            pw.SizedBox(height: 20),

            // ═══ ئاماری AI ═══
            _buildAiAnalysis(
              font: font,
              fontBold: fontBold,
              aiAnalysis: aiAnalysis,
            ),
            pw.SizedBox(height: 20),

            // ═══ ئاماری لایەنی پەیوەندیدار ═══
            _buildAuthorityStats(
              font: font,
              fontBold: fontBold,
              authorityCount: authorityCount,
            ),
            pw.SizedBox(height: 20),

            // ═══ لیستی سکاڵاکان ═══
            pw.Text(
              '📋 لیستی سکاڵاکان',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                color: _primaryDark,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildDataTable(
              font: font,
              fontBold: fontBold,
              complaints: filtered,
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name:
        'complaints_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      _showMessage(context, 'هەڵە لە دروستکردنی PDF: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Header
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildHeader({
    required pw.Font font,
    required pw.Font fontBold,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_primaryDark, PdfColor.fromInt(0xFF2D1B4E)],
        ),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 50,
            height: 50,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [_primaryPink, PdfColor.fromInt(0xFFAD1457)],
              ),
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text(
                '📢',
                style: const pw.TextStyle(fontSize: 24),
              ),
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ڕاپۆرتی سکاڵاکان',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 20,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'ڕێبەری کەلار — شاری کەلار',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: _white70,
                  ),
                ),
                if (fromDate != null && toDate != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'لە ${_formatDate(fromDate)} بۆ ${_formatDate(toDate)}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 9,
                      color: _white60,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: pw.BoxDecoration(
              color: _white10,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'بەروار',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: _white60,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  DateTime.now().toString().substring(0, 10),
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 10,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Footer
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildFooter({
    required pw.Font font,
    required pw.Font fontBold,
    required pw.Context context,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '🏙️ ڕێبەری کەلار — ئەپی فەرمی شاری کەلار',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 9,
              color: _primaryDark,
            ),
          ),
          pw.Text(
            'لاپەڕە ${context.pageNumber} لە ${context.pagesCount}',
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: _grey,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 زانیاری ڕاپۆرت
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildReportInfo({
    required pw.Font font,
    required pw.Font fontBold,
    required int totalComplaints,
    required int totalStatus,
    required int totalCategories,
    required int totalAuthorities,
  }) {
    return pw.Row(
      children: [
        _buildInfoBox(
          icon: '📋',
          label: 'سکاڵاکان',
          value: '$totalComplaints',
          color: _primaryPink,
          font: font,
          fontBold: fontBold,
        ),
        pw.SizedBox(width: 6),
        _buildInfoBox(
          icon: '🎯',
          label: 'دۆخ',
          value: '$totalStatus',
          color: _successGreen,
          font: font,
          fontBold: fontBold,
        ),
        pw.SizedBox(width: 6),
        _buildInfoBox(
          icon: '📂',
          label: 'کەرت',
          value: '$totalCategories',
          color: _primaryBlue,
          font: font,
          fontBold: fontBold,
        ),
        pw.SizedBox(width: 6),
        _buildInfoBox(
          icon: '🏛️',
          label: 'لایەن',
          value: '$totalAuthorities',
          color: _warningOrange,
          font: font,
          fontBold: fontBold,
        ),
      ],
    );
  }

  static pw.Widget _buildInfoBox({
    required String icon,
    required String label,
    required String value,
    required PdfColor color,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          children: [
            pw.Text(icon, style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 16,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: _white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Status Stats
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildStatusStats({
    required pw.Font font,
    required pw.Font fontBold,
    required Map<String, int> statusCount,
    required int total,
  }) {
    final statusColors = {
      'pending': _warningOrange,
      'approved': _successGreen,
      'in_progress': const PdfColor.fromInt(0xFF2ECC71),
      'completed': _primaryBlue,
      'rejected': _dangerRed,
    };

    final statusLabels = {
      'pending': 'چاوەڕوان',
      'approved': 'پەسەندکراو',
      'in_progress': 'لە ئارادایە',
      'completed': 'جێبەجێکرا',
      'rejected': 'ڕەتکراو',
    };

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '📊 ئاماری دۆخ',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 13,
              color: _primaryDark,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: statusCount.entries.map((entry) {
              final status = entry.key;
              final count = entry.value;
              final percent = total > 0 ? (count / total) * 100 : 0.0;
              final color = statusColors[status] ?? PdfColors.grey;

              return pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 3),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: color, width: 1.5),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '$count',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 16,
                          color: color,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        statusLabels[status] ?? status,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 8,
                          color: _grey,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${percent.toStringAsFixed(0)}%',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Status Chart
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildStatusChart({
    required pw.Font font,
    required pw.Font fontBold,
    required Map<String, int> statusCount,
    required int total,
  }) {
    final statusColors = {
      'pending': _warningOrange,
      'approved': _successGreen,
      'in_progress': const PdfColor.fromInt(0xFF2ECC71),
      'completed': _primaryBlue,
      'rejected': _dangerRed,
    };

    final statusLabels = {
      'pending': 'چاوەڕوان',
      'approved': 'پەسەندکراو',
      'in_progress': 'لە ئارادایە',
      'completed': 'جێبەجێکرا',
      'rejected': 'ڕەتکراو',
    };

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '🎯 دۆخی سکاڵاکان',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 12,
              color: _primaryDark,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Column(
            children: statusCount.entries.map((entry) {
              final status = entry.key;
              final count = entry.value;
              final percent = total > 0 ? (count / total) * 100 : 0.0;
              final color = statusColors[status] ?? PdfColors.grey;

              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 10,
                          height: 10,
                          decoration: pw.BoxDecoration(
                            color: color,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          statusLabels[status] ?? status,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9,
                            color: _primaryDark,
                          ),
                        ),
                        pw.Spacer(),
                        pw.Text(
                          '$count (${percent.toStringAsFixed(0)}%)',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    // ✅ Bar — بێ FractionallySizedBox
                    pw.Container(
                      height: 8,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: (percent / 100) * 400,
                            height: 8,
                            decoration: pw.BoxDecoration(
                              color: color,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Category Chart
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildCategoryChart({
    required pw.Font font,
    required pw.Font fontBold,
    required Map<String, int> categoryCount,
  }) {
    final sorted = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();

    if (top.isEmpty) return pw.SizedBox.shrink();

    final maxCount =
    top.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    final colors = [
      _dangerRed,
      _primaryBlue,
      _warningOrange,
      _successGreen,
      const PdfColor.fromInt(0xFF8B5CF6),
      const PdfColor.fromInt(0xFFEC4899),
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '📂 کەرتەکانی سکاڵاکان',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 12,
              color: _primaryDark,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.SizedBox(
            height: 120,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: top.asMap().entries.map((entry) {
                final idx = entry.key;
                final cat = entry.value.key;
                final count = entry.value.value;
                final height = (count / maxCount) * 90 + 20;
                final color = colors[idx % colors.length];

                return pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(
                          '$count',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9,
                            color: color,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          height: height,
                          decoration: pw.BoxDecoration(
                            color: color,
                            borderRadius: const pw.BorderRadius.vertical(
                              top: pw.Radius.circular(4),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          cat.length > 10
                              ? '${cat.substring(0, 10)}...'
                              : cat,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 6,
                            color: _grey,
                          ),
                          textAlign: pw.TextAlign.center,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 AI Analysis
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildAiAnalysis({
    required pw.Font font,
    required pw.Font fontBold,
    required String aiAnalysis,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColor.fromInt(0xFF6C5CE7), _primaryPink],
        ),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: _white20,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Text(
                  '🤖',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'شیکردنەوەی زیرەک (AI Summary)',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 12,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              aiAnalysis,
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: _primaryDark,
                height: 1.6, // ✅ height بەکارهێنراوە نەک lineHeight
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏛️ Authority Stats
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildAuthorityStats({
    required pw.Font font,
    required pw.Font fontBold,
    required Map<String, int> authorityCount,
  }) {
    final sorted = authorityCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '🏛️ لایەنە پەیوەندیدارەکان',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 12,
              color: _primaryDark,
            ),
          ),
          pw.SizedBox(height: 8),
          ...sorted.map((entry) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 8,
                    height: 8,
                    decoration: const pw.BoxDecoration(
                      color: _primaryBlue,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(
                      entry.key,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 9,
                        color: _primaryDark,
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _primaryBlue,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      '${entry.value}',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 Data Table
  // ═══════════════════════════════════════════════════════════
  static pw.Widget _buildDataTable({
    required pw.Font font,
    required pw.Font fontBold,
    required List<Map<String, dynamic>> complaints,
  }) {
    final statusLabels = {
      'pending': 'چاوەڕوان',
      'approved': 'پەسەندکراو',
      'in_progress': 'لە ئارادایە',
      'completed': 'جێبەجێکرا',
      'rejected': 'ڕەتکراو',
    };

    return pw.TableHelper.fromTextArray(
      headers: [
        '#',
        'جۆری سکاڵا',
        'لایەنی پەیوەندیدار',
        'بەروار',
        'دۆخ',
      ],
      data: complaints.reversed.toList().asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final c = entry.value;
        final status = c['status']?.toString() ?? 'pending';
        final createdAt = c['created_at'] != null
            ? DateTime.tryParse(c['created_at'].toString())
            : null;

        final title = c['title']?.toString() ?? '-';

        return [
          idx.toString(),
          title.length > 30 ? '${title.substring(0, 30)}...' : title,
          c['responsible_authority']?.toString() ?? '-',
          createdAt != null
              ? '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}'
              : '-',
          statusLabels[status] ?? status,
        ];
      }).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(
        font: fontBold,
        color: PdfColors.white,
        fontSize: 9,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: _primaryDark,
      ),
      cellAlignment: pw.Alignment.centerRight,
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      cellPadding: const pw.EdgeInsets.all(5),
      oddRowDecoration: const pw.BoxDecoration(
        color: _lightGrey,
      ),
      headerAlignment: pw.Alignment.centerRight,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ Helpers
  // ═══════════════════════════════════════════════════════════
  static String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  static void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}