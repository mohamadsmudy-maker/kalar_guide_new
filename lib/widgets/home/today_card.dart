// lib/widgets/home/today_card.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/prayer/kalar_prayer_times.dart';
import '../../utils/place_display.dart';

/// ☀️ کارتی «ئەمڕۆ» لە شاشەی سەرەکی: سڵاو بەپێی کات، بەروار و بانگی داهاتوو
/// (کاتەکان لە خشتەی فەرمی ناو ئەپەوە دێن؛ پێویستی بە ئینتەرنێت نییە)
class TodayCard extends StatefulWidget {
  const TodayCard({super.key, this.onTap, this.now});

  final VoidCallback? onTap;

  /// تەنها بۆ تاقیکردنەوە
  final DateTime Function()? now;

  @override
  State<TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<TodayCard> {
  Timer? _tick;

  static const _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _names = {
    'fajr': 'بەیانی',
    'dhuhr': 'نیوەڕۆ',
    'asr': 'عەسر',
    'maghrib': 'ئێوارە',
    'isha': 'خەوتنان',
  };
  static const _months = [
    'کانوونی دووەم', 'شوبات', 'ئازار', 'نیسان', 'ئایار', 'حوزەیران',
    'تەممووز', 'ئاب', 'ئەیلوول', 'تشرینی یەکەم', 'تشرینی دووەم', 'کانوونی یەکەم',
  ];
  static const _weekdays = [
    'دووشەممە', 'سێشەممە', 'چوارشەممە', 'پێنجشەممە', 'هەینی', 'شەممە', 'یەکشەممە',
  ];

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = _now.hour;
    if (h >= 4 && h < 12) return tr('بەیانیت باش');
    if (h >= 12 && h < 17) return tr('نیوەڕۆت باش');
    if (h >= 17 && h < 21) return tr('ئێوارەت باش');
    return tr('شەوت باش');
  }

  IconData get _greetingIcon {
    final h = _now.hour;
    if (h >= 6 && h < 17) return Icons.wb_sunny_rounded;
    if (h >= 17 && h < 20) return Icons.wb_twilight_rounded;
    return Icons.nightlight_round;
  }

  /// (ناو، کات، ماوە)
  (String, DateTime) _nextPrayer() {
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    for (final id in _prayers) {
      final at = KalarPrayerTimes.at(today, id);
      if (at.isAfter(now)) return (id, at);
    }
    final tomorrow = today.add(const Duration(days: 1));
    return ('fajr', KalarPrayerTimes.at(tomorrow, 'fajr'));
  }

  String _remaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60) + (d.inSeconds.remainder(60) > 0 ? 1 : 0);
    if (h <= 0) return trf('{0} خولەکی ماوە', [PlaceDisplay.digits(m.clamp(1, 59))]);
    return trf('{0} کاتژمێر و {1} خولەک', [PlaceDisplay.digits(h), PlaceDisplay.digits(m.clamp(0, 59))]);
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final (id, at) = _nextPrayer();
    final hm = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final time = KalarPrayerTimes.format12(hm, kurdishDigits: AppLang.isRtl);
    final date = '${tr(_weekdays[now.weekday - 1])}، '
        '${PlaceDisplay.digits(now.day)} ${tr(_months[now.month - 1])}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: widget.onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // سڵاو + بەروار
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(_greetingIcon, color: const Color(0xFFFFD54F), size: 20),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _greeting,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // بانگی داهاتوو
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.mosque_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          '${tr(_names[id]!)} • $time',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        _remaining(at.difference(now)),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
