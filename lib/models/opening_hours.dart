import 'package:flutter/foundation.dart';

/// کاتی کارکردنی شوێنێک. هەفتەکە لە شەممەوە دەست پێدەکات (وەک عێراق).
///
/// JSON (لە `dukan.opening_hours`):
/// `{"is24h": false, "days": {"sat": {"open": "08:00", "close": "21:00"}, "fri": null}}`
/// ڕۆژی نەنووسراو یان null = داخراوە. ئەگەر `close` پێش `open` بێت (٢٢:٠٠ ← ٠٢:٠٠)
/// واتە دوای نیوەشەو دەخایەنێت.
@immutable
class OpeningHours {
  const OpeningHours({this.is24h = false, this.days = const {}});

  final bool is24h;
  final Map<String, DayHours?> days;

  static const List<String> dayKeys = ['sat', 'sun', 'mon', 'tue', 'wed', 'thu', 'fri'];

  /// ناوی ڕۆژەکان بە کوردی (کلیلی tr)
  static const Map<String, String> dayNames = {
    'sat': 'شەممە',
    'sun': 'یەکشەممە',
    'mon': 'دووشەممە',
    'tue': 'سێشەممە',
    'wed': 'چوارشەممە',
    'thu': 'پێنجشەممە',
    'fri': 'هەینی',
  };

  /// DateTime.weekday (دووشەممە=١ ... یەکشەممە=٧) ← کلیلی ڕۆژ
  static String keyOfWeekday(int weekday) =>
      const {6: 'sat', 7: 'sun', 1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu', 5: 'fri'}[weekday]!;

  bool get isEmpty => !is24h && days.values.every((d) => d == null);

  static OpeningHours? fromJson(dynamic json) {
    if (json is! Map) return null;
    final raw = json['days'];
    final days = <String, DayHours?>{};
    if (raw is Map) {
      for (final k in dayKeys) {
        final d = DayHours.fromJson(raw[k]);
        if (d != null) days[k] = d;
      }
    }
    final h = OpeningHours(is24h: json['is24h'] == true, days: days);
    return h.isEmpty ? null : h;
  }

  Map<String, dynamic> toJson() => {
        'is24h': is24h,
        'days': {
          for (final k in dayKeys) k: days[k]?.toJson(),
        },
      };

  OpeningHours copyWith({bool? is24h, Map<String, DayHours?>? days}) =>
      OpeningHours(is24h: is24h ?? this.is24h, days: days ?? this.days);

  static int minutes(String hm) {
    final p = hm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  /// ئایا ئێستا کراوەیە؟ و کەی دەگۆڕێت؟
  OpenStatus statusAt(DateTime now) {
    if (is24h) return const OpenStatus(open: true);
    final today = DateTime(now.year, now.month, now.day);
    final nowMin = now.hour * 60 + now.minute;

    // کۆتایی ئەو ماوەیەی دوێنێ کە دوای نیوەشەو دەخایەنێت
    final yKey = keyOfWeekday(today.subtract(const Duration(days: 1)).weekday);
    final y = days[yKey];
    if (y != null && y.crossesMidnight && nowMin < minutes(y.close)) {
      return OpenStatus(open: true, changeAt: today.add(Duration(minutes: minutes(y.close))));
    }

    final t = days[keyOfWeekday(today.weekday)];
    if (t != null) {
      final o = minutes(t.open), c = minutes(t.close);
      if (t.crossesMidnight) {
        if (nowMin >= o) {
          return OpenStatus(
              open: true, changeAt: today.add(Duration(days: 1, minutes: c)));
        }
      } else if (nowMin >= o && nowMin < c) {
        return OpenStatus(open: true, changeAt: today.add(Duration(minutes: c)));
      }
    }

    // داخراوە: یەکەم کردنەوەی داهاتوو لە ٧ ڕۆژی داهاتوودا
    for (var i = 0; i < 8; i++) {
      final day = today.add(Duration(days: i));
      final d = days[keyOfWeekday(day.weekday)];
      if (d == null) continue;
      final at = day.add(Duration(minutes: minutes(d.open)));
      if (at.isAfter(now)) return OpenStatus(open: false, changeAt: at);
    }
    return const OpenStatus(open: false);
  }
}

@immutable
class DayHours {
  const DayHours(this.open, this.close);
  final String open;
  final String close;

  bool get crossesMidnight => OpeningHours.minutes(close) <= OpeningHours.minutes(open);

  static final RegExp _hm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  static DayHours? fromJson(dynamic j) {
    if (j is! Map) return null;
    final o = '${j['open'] ?? ''}', c = '${j['close'] ?? ''}';
    if (!_hm.hasMatch(o) || !_hm.hasMatch(c)) return null;
    return DayHours(o, c);
  }

  Map<String, dynamic> toJson() => {'open': open, 'close': close};

  @override
  bool operator ==(Object other) =>
      other is DayHours && other.open == open && other.close == close;
  @override
  int get hashCode => Object.hash(open, close);
}

@immutable
class OpenStatus {
  const OpenStatus({required this.open, this.changeAt});
  final bool open;

  /// کاتی داخستن (ئەگەر کراوەیە) یان کردنەوەی داهاتوو (ئەگەر داخراوە)
  final DateTime? changeAt;
}
