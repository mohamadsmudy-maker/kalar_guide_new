// lib/screens/prayer/prayer_month_share.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/prayer/kalar_prayer_times.dart';

/// 📤 خشتەی مانگانەی کاتەکانی نوێژ وەک وێنە — بۆ واتسئاپ و مزگەوتەکان
class PrayerMonthSharePage extends StatefulWidget {
  const PrayerMonthSharePage({
    super.key,
    required this.year,
    required this.month,
    required this.monthName,
    this.lat = KalarPrayerTimes.kalarLat,
    this.lng = KalarPrayerTimes.kalarLng,
    this.kurdishDigits = false,
  });

  final int year;
  final int month;
  final String monthName;
  final double lat;
  final double lng;
  final bool kurdishDigits;

  @override
  State<PrayerMonthSharePage> createState() => _PrayerMonthSharePageState();
}

class _PrayerMonthSharePageState extends State<PrayerMonthSharePage> {
  final GlobalKey _boundary = GlobalKey();
  bool _busy = false;

  static const _cols = ['بەیانی', 'خۆرهەڵاتن', 'نیوەڕۆ', 'عەسر', 'ئێوارە', 'خەوتنان'];
  static const _weekdays = ['دووشەممە', 'سێشەممە', 'چوارشەممە', 'پێنجشەممە', 'هەینی', 'شەممە', 'یەکشەممە'];

  String _d(String s) => widget.kurdishDigits ? KalarPrayerTimes.toKurdishDigits(s) : s;

  /// بێ پ.ن/د.ن بۆ ئەوەی خشتەکە تەسک بێت (وەک ئامۆژگاری)
  String _t(String hm) {
    final p = hm.split(':');
    final h = int.parse(p[0]) % 12 == 0 ? 12 : int.parse(p[0]) % 12;
    return _d('$h:${p[1]}');
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kalar_prayer_${widget.year}_${widget.month}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'کاتەکانی بانگی کەلار — ${widget.monthName} ${widget.year}\nئەپی ڕێبەری کەلار',
      );
    } catch (e) {
      debugPrint('❌ share month: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هاوبەشکردن سەرکەوتوو نەبوو')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(widget.year, widget.month);
    final today = DateUtils.dateOnly(DateTime.now());
    var anyCalculated = false;

    final rows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(color: Color(0xFFEF8A3C)),
        children: [
          _cell('ڕۆژ', header: true),
          for (final c in _cols) _cell(c, header: true),
        ],
      ),
    ];
    for (var d = 1; d <= days; d++) {
      final date = DateTime(widget.year, widget.month, d);
      final day = KalarPrayerTimes.forDay(date, lat: widget.lat, lng: widget.lng);
      if (!day.isOfficial) anyCalculated = true;
      final isFriday = date.weekday == DateTime.friday;
      final isToday = date == today;
      rows.add(TableRow(
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFFFFE0B2)
              : isFriday
                  ? const Color(0xFFFBE3E3)
                  : (d.isEven ? Colors.white : const Color(0xFFFDF6EC)),
        ),
        children: [
          _cell('${_d('$d')} ${_weekdays[date.weekday - 1]}', bold: true),
          for (final id in KalarPrayerTimes.ids) _cell(_t(day.times[id]!)),
        ],
      ));
    }

    final sheet = RepaintBoundary(
      key: _boundary,
      child: Container(
        width: 720,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'کاتەکانی بانگ — کەلار',
                style: TextStyle(color: Color(0xFF1A1B2E), fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.monthName} ${_d('${widget.year}')}',
                style: const TextStyle(color: Color(0xFFEF8A3C), fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Table(
                border: TableBorder.all(color: const Color(0xFFE8DCCB)),
                columnWidths: const {0: FlexColumnWidth(1.6)},
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: rows,
              ),
              const SizedBox(height: 10),
              Text(
                anyCalculated
                    ? 'سەرچاوە: amozhgary.tv و هەژماری ئەپ • ئەپی ڕێبەری کەلار'
                    : 'سەرچاوە: amozhgary.tv • ئەپی ڕێبەری کەلار',
                style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1421),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          title: Text('خشتەی ${widget.monthName}', style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: InteractiveViewer(
          constrained: false,
          minScale: 0.3,
          maxScale: 3,
          boundaryMargin: const EdgeInsets.all(40),
          child: Padding(padding: const EdgeInsets.all(12), child: sheet),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : _share,
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: Colors.black,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.share_rounded),
          label: const Text('هاوبەشکردن', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  Widget _cell(String text, {bool header = false, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            color: header ? Colors.white : const Color(0xFF1A1B2E),
            fontSize: header ? 14 : 14,
            fontWeight: header || bold ? FontWeight.w900 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
}
