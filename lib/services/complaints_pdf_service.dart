import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'ai_service.dart';

/// 📄 ڕاپۆرتی PDF ی سکاڵاکان
///
/// دیزاینی ئارام و یەکگرتوو لەگەڵ ئەپەکە. چەند چاکسازییەک:
/// • فۆنت لەناو ئەپەکەدایە (بێ ئینتەرنێت کار دەکات)
/// • هیچ ڕەنگێکی شەفاف نییە (PDF ی ئەندرۆید شەفافیەت بە سپی پیشان دەدات)
/// • دەقی AI پاک دەکرێتەوە (ئیمۆجی و هێما کە فۆنتەکە نایانناسێت → چوارگۆشە)
/// • لاپەڕەی یەکەم کورتەی ڕاپۆرتە و بە تەواوی دەگونجێت؛ خشتەکە لە لاپەڕەکانی دواتر
class ComplaintsPdfService {
  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕەنگەکان (هەموویان ڕەق)
  // ═══════════════════════════════════════════════════════════
  static const PdfColor _blue = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor _blueDark = PdfColor.fromInt(0xFF1565C0);
  static const PdfColor _blueSoft = PdfColor.fromInt(0xFFE8F2FD);
  static const PdfColor _onBlueSub = PdfColor.fromInt(0xFFD3E7FB);
  static const PdfColor _ink = PdfColor.fromInt(0xFF1A1A2E);
  static const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _line = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _zebra = PdfColor.fromInt(0xFFF7F8FA);
  static const PdfColor _card = PdfColor.fromInt(0xFFF4F6FA);

  static const PdfColor _orange = PdfColor.fromInt(0xFFD9822B);
  static const PdfColor _green = PdfColor.fromInt(0xFF0F9D7A);
  static const PdfColor _red = PdfColor.fromInt(0xFFDC3545);
  static const PdfColor _teal = PdfColor.fromInt(0xFF00897B);
  static const PdfColor _purple = PdfColor.fromInt(0xFF6C5CE7);

  static const _statusOrder = [
    'pending',
    'approved',
    'in_progress',
    'completed',
    'rejected',
  ];

  static const _statusLabels = {
    'pending': 'چاوەڕوان',
    'approved': 'پەسەندکراو',
    'in_progress': 'لە ئارادایە',
    'completed': 'جێبەجێکرا',
    'rejected': 'ڕەتکراو',
  };

  static const _statusColors = {
    'pending': _orange,
    'approved': _green,
    'in_progress': _teal,
    'completed': _blue,
    'rejected': _red,
  };

  static const _statusTints = {
    'pending': PdfColor.fromInt(0xFFFCF1E3),
    'approved': PdfColor.fromInt(0xFFE3F4EF),
    'in_progress': PdfColor.fromInt(0xFFE0F1EF),
    'completed': PdfColor.fromInt(0xFFE3F0FC),
    'rejected': PdfColor.fromInt(0xFFFBE6E8),
  };

  // ═══════════════════════════════════════════════════════════
  // 🧰 یارمەتیدەرەکان
  // ═══════════════════════════════════════════════════════════
  /// ژمارە بە پیتی کوردی/عەرەبی («١٤» نەک «14»)
  static String ku(Object n) => n.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
      );

  static String _date(DateTime? d) => d == null
      ? '-'
      : ku('${d.year}/${d.month.toString().padLeft(2, '0')}/'
          '${d.day.toString().padLeft(2, '0')}');

  /// ئاگادار: «…» (U+2026) لە پاکێجی bidi ی pdf کڕاش دەدات کاتێک فۆنتی فۆڵبەک هەبێت
  /// (NFKC دەیکات بە سێ خاڵ و درێژییەکە ناگونجێت)، بۆیە سێ خاڵی ASCII بەکاردێنین.
  static String _cut(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;

  /// دەقی AI بۆ چەند دێڕێکی پاک: markdown و هێمای نەناسراو لادەبات
  static List<String> cleanAiLines(String raw, {int maxLines = 5}) {
    // تەنها پیتی ئاسایی: عەرەبی/کوردی، لاتینی، ژمارە، خاڵبەندی. (فۆرمە
    // پێشکەشکراوەکانی عەرەبی U+FB50.. لێرە ڕێگەپێنەدراون: NFKC کڕاشی دەدات)
    final allowed = RegExp(
      r'[^؀-ۿݐ-ݿA-Za-z0-9\s.,:;!?()\-/%،؛؟]',
    );
    final out = <String>[];
    for (var line in raw.split(RegExp(r'[\r\n]+'))) {
      line = line
          .replaceAll(RegExp(r'[*_`#>]+'), '')
          .replaceFirst(RegExp(r'^\s*[-•·–]+\s*'), '')
          .replaceFirst(RegExp(r'^\s*\d+[.)]\s*'), '')
          .replaceAll(allowed, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (line.length >= 3) out.add(_cut(line, 220));
      if (out.length >= maxLines) break;
    }
    return out;
  }

  static Future<pw.Font> _loadFont(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));

  // ═══════════════════════════════════════════════════════════
  // 📄 دروستکردنی ڕاپۆرت (بێ UI — تاقیکراوەتەوە)
  // ═══════════════════════════════════════════════════════════
  static Future<Uint8List> buildReportBytes({
    required List<Map<String, dynamic>> complaints,
    DateTime? fromDate,
    DateTime? toDate,
    List<String> aiLines = const [],
    DateTime? now,
  }) async {
    final font = await _loadFont('assets/fonts/NotoNaskhArabic-Regular.ttf');
    // فۆنتی NotoNaskh لیستی کورتکراوە: پیتی لاتینی و هێمای ( ) / # — … نییە
    final latin = await _loadFont('assets/fonts/Roboto-Regular.ttf');
    final today = now ?? DateTime.now();

    // ── ئامارەکان ──
    final statusCount = <String, int>{};
    final categoryCount = <String, int>{};
    final authorityCount = <String, int>{};
    for (final c in complaints) {
      final s = c['status']?.toString() ?? 'pending';
      statusCount[s] = (statusCount[s] ?? 0) + 1;
      final cat = (c['title']?.toString() ?? '').trim();
      final a = (c['responsible_authority']?.toString() ?? '').trim();
      categoryCount[cat.isEmpty ? 'نەناسراو' : cat] =
          (categoryCount[cat.isEmpty ? 'نەناسراو' : cat] ?? 0) + 1;
      authorityCount[a.isEmpty ? 'نەناسراو' : a] =
          (authorityCount[a.isEmpty ? 'نەناسراو' : a] ?? 0) + 1;
    }
    final total = complaints.length;
    final done = (statusCount['completed'] ?? 0);

    final theme =
        pw.ThemeData.withFont(base: font, bold: font, fontFallback: [latin]);
    final pdf = pw.Document(
      title: 'ڕاپۆرتی سکاڵاکان',
      author: 'ڕێبەری کەلار',
    );

    pw.Widget text(String s,
            {double size = 10, PdfColor color = _ink, pw.TextAlign? align}) =>
        pw.Text(s,
            textAlign: align,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
                font: font,
                fontFallback: [latin],
                fontSize: size,
                color: color,
                lineSpacing: 2));

    // ── سەرپەڕە ──
    pw.Widget header() => pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: pw.BoxDecoration(
            color: _blue,
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 38,
                height: 38,
                alignment: pw.Alignment.center,
                decoration: const pw.BoxDecoration(
                    color: _blueDark, shape: pw.BoxShape.circle),
                child: text('!', size: 20, color: PdfColors.white),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    text('ڕاپۆرتی سکاڵاکان', size: 19, color: PdfColors.white),
                    pw.SizedBox(height: 3),
                    text('ڕێبەری کەلار — شاری کەلار',
                        size: 9.5, color: _onBlueSub),
                    if (fromDate != null && toDate != null)
                      text('لە ${_date(fromDate)} بۆ ${_date(toDate)}',
                          size: 9, color: _onBlueSub),
                  ],
                ),
              ),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                    color: _blueDark,
                    borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(children: [
                  text('بەرواری ڕاپۆرت', size: 7.5, color: _onBlueSub),
                  pw.SizedBox(height: 2),
                  text(_date(today), size: 10, color: PdfColors.white),
                ]),
              ),
            ],
          ),
        );

    pw.Widget footer(pw.Context ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _line, width: 0.8))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              text('ڕێبەری کەلار — ئەپی فەرمی شاری کەلار',
                  size: 8, color: _grey),
              text('لاپەڕە ${ku(ctx.pageNumber)} لە ${ku(ctx.pagesCount)}',
                  size: 8, color: _grey),
            ],
          ),
        );

    pw.Widget sectionTitle(String s) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: text(s, size: 12, color: _ink),
        );

    pw.Widget panel({required pw.Widget child}) => pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: _line, width: 0.8),
          ),
          child: child,
        );

    // ── کارتی ژمارە ──
    pw.Widget kpi(String label, int value, PdfColor color, PdfColor tint) =>
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            decoration: pw.BoxDecoration(
                color: tint, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Column(children: [
              text(ku(value), size: 20, color: color),
              pw.SizedBox(height: 2),
              text(label, size: 8.5, color: _grey),
            ]),
          ),
        );

    // ── ستوونی ڕێژەیی (بەبێ پانیی چەسپاو) ──
    pw.Widget bar(double fraction, PdfColor color, {double h = 7}) {
      final f = fraction.clamp(0.0, 1.0);
      final a = (f * 1000).round();
      return pw.Container(
        height: h,
        decoration: pw.BoxDecoration(
            color: _line, borderRadius: pw.BorderRadius.circular(h / 2)),
        child: pw.Row(children: [
          if (a > 0)
            pw.Expanded(
              flex: a,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: pw.BorderRadius.circular(h / 2)),
              ),
            ),
          if (a < 1000) pw.Expanded(flex: 1000 - a, child: pw.SizedBox()),
        ]),
      );
    }

    pw.Widget barRow(String label, int count, int max, PdfColor color,
            {int? percent}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 7),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Container(
                    width: 8,
                    height: 8,
                    decoration: pw.BoxDecoration(
                        color: color,
                        borderRadius: pw.BorderRadius.circular(2))),
                pw.SizedBox(width: 6),
                pw.Expanded(child: text(_cut(label, 42), size: 9)),
                if (percent != null) ...[
                  text('${ku(percent)}٪', size: 8, color: _grey),
                  pw.SizedBox(width: 8),
                ],
                text(ku(count), size: 9.5, color: color),
              ]),
              pw.SizedBox(height: 3),
              bar(max == 0 ? 0 : count / max, color),
            ],
          ),
        );

    List<MapEntry<String, int>> top(Map<String, int> m, int n) =>
        (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(n)
            .toList();

    final statusKeys = [
      ..._statusOrder.where(statusCount.containsKey),
      ...statusCount.keys.where((k) => !_statusOrder.contains(k)),
    ];
    final cats = top(categoryCount, 6);
    final auths = top(authorityCount, 6);
    final catMax = cats.isEmpty ? 0 : cats.first.value;
    final authMax = auths.isEmpty ? 0 : auths.first.value;
    final catColors = [_blue, _green, _orange, _purple, _teal, _red];

    // ══ لاپەڕەی ١: کورتە ══
    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            header(),
            pw.SizedBox(height: 14),
            pw.Row(children: [
              kpi('هەموو سکاڵاکان', total, _blue, _blueSoft),
              pw.SizedBox(width: 8),
              kpi('چاوەڕوان', statusCount['pending'] ?? 0, _orange,
                  _statusTints['pending']!),
              pw.SizedBox(width: 8),
              kpi('جێبەجێکرا', done, _green, _statusTints['approved']!),
              pw.SizedBox(width: 8),
              kpi('ڕەتکراو', statusCount['rejected'] ?? 0, _red,
                  _statusTints['rejected']!),
            ]),
            pw.SizedBox(height: 14),
            panel(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  sectionTitle('دۆخی سکاڵاکان'),
                  for (final k in statusKeys)
                    barRow(
                      _statusLabels[k] ?? k,
                      statusCount[k]!,
                      total,
                      _statusColors[k] ?? _grey,
                      percent: total == 0
                          ? null
                          : (statusCount[k]! * 100 / total).round(),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: panel(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        sectionTitle('جۆرەکانی سکاڵا'),
                        for (var i = 0; i < cats.length; i++)
                          barRow(cats[i].key, cats[i].value, catMax,
                              catColors[i % catColors.length]),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: panel(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        sectionTitle('لایەنە پەیوەندیدارەکان'),
                        for (final a in auths)
                          barRow(a.key, a.value, authMax, _blueDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (aiLines.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                    color: _card, borderRadius: pw.BorderRadius.circular(12)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    sectionTitle('شیکردنەوەی زیرەک'),
                    for (final l in aiLines)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 4),
                              child: pw.Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const pw.BoxDecoration(
                                      color: _purple,
                                      shape: pw.BoxShape.circle)),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Expanded(child: text(l, size: 9.5)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            pw.Spacer(),
            footer(ctx),
          ],
        ),
      ),
    );

    // ══ لاپەڕەکانی دواتر: خشتەی سکاڵاکان ══
    final rows = complaints.reversed.toList(); // نوێترین لە سەرەوە
    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              text('لیستی سکاڵاکان', size: 13, color: _blueDark),
              text('${ku(total)} سکاڵا', size: 9, color: _grey),
            ],
          ),
        ),
        footer: footer,
        build: (ctx) => [
          // pw.Directionality(ltr): ستوونەکان بە ڕێزی فیزیکی چەپ→ڕاست دادەنرێن (ڕێک
          // وەک خۆیان لە columnWidths نووسراون)؛ دەقەکان خۆیان RTL ن.
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Table(
              // pw.Table لە چەپەوە بۆ ڕاست دایدەنێت، بۆیە ستوونەکان بە پێچەوانەوە
              // ڕیز کراون تا «#» لای ڕاست بێت (ئاراستەی کوردی)
              columnWidths: {
                0: const pw.FixedColumnWidth(64),
                1: const pw.FixedColumnWidth(62),
                2: const pw.FlexColumnWidth(2.4),
                3: const pw.FlexColumnWidth(3.2),
                4: const pw.FixedColumnWidth(26),
              },
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: _line, width: 0.6),
                bottom: pw.BorderSide(color: _line, width: 0.6),
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _blue),
                  children: [
                    for (final h in [
                      'دۆخ',
                      'بەروار',
                      'لایەنی پەیوەندیدار',
                      'جۆری سکاڵا',
                      '#',
                    ])
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 7),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: text(h, size: 8.5, color: PdfColors.white),
                        ),
                      ),
                  ],
                ),
                for (var i = 0; i < rows.length; i++)
                  () {
                    final c = rows[i];
                    final s = c['status']?.toString() ?? 'pending';
                    final created =
                        DateTime.tryParse(c['created_at']?.toString() ?? '');
                    final color = _statusColors[s] ?? _grey;
                    pw.Widget cell(pw.Widget w) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          child: pw.Align(
                              alignment: pw.Alignment.centerRight, child: w),
                        );
                    return pw.TableRow(
                      decoration: i.isOdd
                          ? const pw.BoxDecoration(color: _zebra)
                          : null,
                      children: [
                        cell(text(_statusLabels[s] ?? s,
                            size: 8.5, color: color)),
                        cell(text(_date(created), size: 8.5, color: _grey)),
                        cell(text(
                            _cut(c['responsible_authority']?.toString() ?? '-',
                                26),
                            size: 8.5)),
                        cell(text(_cut(c['title']?.toString() ?? '-', 34),
                            size: 8.5)),
                        cell(text(ku(i + 1), size: 8, color: _grey)),
                      ],
                    );
                  }(),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 ڕاپۆرتی PDF (UI)
  // ═══════════════════════════════════════════════════════════
  static Future<void> generateReport({
    required BuildContext context,
    required List<Map<String, dynamic>> complaints,
    DateTime? fromDate,
    DateTime? toDate,
    String? statusFilter,
  }) async {
    try {
      var filtered = List<Map<String, dynamic>>.of(complaints);
      if (fromDate != null && toDate != null) {
        filtered = filtered.where((item) {
          final createdAt =
              DateTime.tryParse(item['created_at']?.toString() ?? '');
          if (createdAt == null) return false;
          return createdAt
                  .isAfter(fromDate.subtract(const Duration(days: 1))) &&
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

      // ✅ شیکردنەوەی AI (ئارەزوومەندانە؛ ئەگەر شکستی هێنا ڕاپۆرتەکە بەبێ ئەو دروست دەبێت)
      var aiLines = <String>[];
      try {
        final summary = filtered
            .take(20)
            .map((c) => "${c['title']}: ${c['status']}")
            .join('\n');
        final raw = await AiService.askAdminAI(
          'ئەم کورتەیەی سکاڵاکان شیکار بکە و تەنها ٣ خاڵی گرنگ بە کوردی سۆرانی بنووسە:',
          summary,
        ).timeout(const Duration(seconds: 25));
        aiLines = cleanAiLines(raw, maxLines: 3);
      } catch (_) {}

      final bytes = await buildReportBytes(
        complaints: filtered,
        fromDate: fromDate,
        toDate: toDate,
        aiLines: aiLines,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'complaints_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      if (context.mounted) _showMessage(context, 'هەڵە لە دروستکردنی PDF: $e');
    }
  }

  static void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
