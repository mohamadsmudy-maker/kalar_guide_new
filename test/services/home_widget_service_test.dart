import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/l10n/tr.dart';
import 'package:kalar_guide_new/services/home_widget_service.dart';

void main() {
  final hm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  test('ئەمڕۆ و بەیانی: بەروار و هەر شەش کاتی نوێژ', () {
    final d = HomeWidgetService.prayerData(DateTime(2026, 11, 30, 14, 5));
    expect(d['d0_date'], '2026-11-30');
    expect(d['d1_date'], '2026-12-01'); // مانگ دەگۆڕێت
    for (final id in HomeWidgetService.prayerIds) {
      expect(d['d0_$id'], matches(hm), reason: 'd0_$id');
      expect(d['d1_$id'], matches(hm), reason: 'd1_$id');
      expect(d['name_$id'], isNotEmpty);
    }
  });

  test('کاتی نوێژ بە ڕیز: بەیانی < خۆرهەڵاتن < ... < عیشا', () {
    final d = HomeWidgetService.prayerData(DateTime(2026, 11, 13));
    final times = [for (final id in HomeWidgetService.prayerIds) d['d0_$id']!];
    final sorted = [...times]..sort();
    expect(times, sorted);
  });

  test('ناو و دەقەکان بە زمانی ئێستا، و کلیلەکانی Kotlin هەن', () {
    final d = HomeWidgetService.prayerData(DateTime(2026, 11, 13));
    for (final k in [
      'lang', 'digits', 'title', 'next_label', 'tpl_min', 'tpl_hm',
      'd0_date', 'd1_date',
    ]) {
      expect(d.containsKey(k), isTrue, reason: k);
    }
    expect(d['tpl_min'], contains('{0}'));
    expect(d['tpl_hm'], allOf(contains('{0}'), contains('{1}')));
    expect(d['digits'], AppLang.isRtl ? '1' : '0');
  });
}
