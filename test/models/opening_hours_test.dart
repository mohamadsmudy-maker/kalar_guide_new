import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/opening_hours.dart';

void main() {
  // هەفتە: شەممە-پێنجشەممە ٠٨-٢١، هەینی داخراو، یەکشەممە شەوانە ٢٢-٠٢
  OpeningHours shop() => OpeningHours.fromJson({
        'is24h': false,
        'days': {
          for (final k in ['sat', 'mon', 'tue', 'wed', 'thu'])
            k: {'open': '08:00', 'close': '21:00'},
          'sun': {'open': '22:00', 'close': '02:00'},
          'fri': null,
        },
      })!;

  // 2026-11-14 شەممەیە
  final sat = DateTime(2026, 11, 14);

  test('JSON: بەتاڵ و هەڵە → null، دروست → خوێندنەوە و گەڕانەوە', () {
    expect(OpeningHours.fromJson(null), isNull);
    expect(OpeningHours.fromJson({'days': {}}), isNull);
    expect(OpeningHours.fromJson({'days': {'sat': {'open': '8:00', 'close': 'x'}}}), isNull);
    final h = shop();
    expect(OpeningHours.fromJson(h.toJson())!.days['sat'], const DayHours('08:00', '21:00'));
    expect(h.days['fri'], isNull);
  });

  test('کراوە لە ناو ماوەکە، دەگۆڕێت لە کاتی داخستن', () {
    final s = shop().statusAt(sat.add(const Duration(hours: 12)));
    expect(s.open, isTrue);
    expect(s.changeAt, sat.add(const Duration(hours: 21)));
  });

  test('داخراو پێش کردنەوە: ئەمڕۆ دەکرێتەوە', () {
    final s = shop().statusAt(sat.add(const Duration(hours: 6)));
    expect(s.open, isFalse);
    expect(s.changeAt, sat.add(const Duration(hours: 8)));
  });

  test('دوای داخستن: بەیانی دەکرێتەوە', () {
    final s = shop().statusAt(sat.add(const Duration(hours: 22)));
    expect(s.open, isFalse);
    expect(s.changeAt, DateTime(2026, 11, 15, 22)); // یەکشەممە ٢٢:٠٠ (شەوانە)
  });

  test('هەینی داخراوە و دووشەممە دەکرێتەوە', () {
    final fri = DateTime(2026, 11, 20, 12);
    final s = shop().statusAt(fri);
    expect(s.open, isFalse);
    expect(s.changeAt, DateTime(2026, 11, 21, 8)); // شەممە
  });

  test('شەوانە: دوای نیوەشەو هێشتا کراوەیە و لە بەیانیدا دەگۆڕێت', () {
    // دووشەممە ٠١:٠٠ — ماوەکەی یەکشەممە ٢٢-٠٢ هێشتا بەردەوامە
    final mon1 = DateTime(2026, 11, 16, 1);
    final s = shop().statusAt(mon1);
    expect(s.open, isTrue);
    expect(s.changeAt, DateTime(2026, 11, 16, 2));
    // یەکشەممە ٢٣:٠٠ کراوە، تا ٠٢:٠٠ی دووشەممە
    final sun23 = DateTime(2026, 11, 15, 23);
    expect(shop().statusAt(sun23).changeAt, DateTime(2026, 11, 16, 2));
  });

  test('٢٤ سەعات هەمیشە کراوەیە', () {
    expect(const OpeningHours(is24h: true).statusAt(sat).open, isTrue);
  });
}
