// test/utils/place_display_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/utils/place_display.dart';

void main() {
  group('ناونیشان', () {
    test('«کلار» دەبێت بە «کەلار»، وشەی تر دەستی لێنادرێت', () {
      expect(PlaceDisplay.address('کلار'), 'کەلار');
      expect(PlaceDisplay.address('کلار، شەقامی سەرەکی'), 'کەلار، شەقامی سەرەکی');
      expect(PlaceDisplay.address('کەلار'), 'کەلار');
      expect(PlaceDisplay.address('کلارەکان'), 'کلارەکان');
      expect(PlaceDisplay.address(null), 'کەلار');
      expect(PlaceDisplay.address('  '), 'کەلار');
    });
  });

  group('ئایکۆن', () {
    test('ناوی تایبەتی شوێن پێش بەشی گشتی', () {
      expect(PlaceDisplay.iconForPlace({'name': 'بنکەی ئاگرکوژێنەوەی کەلار', 'category': 'فەرمانگەکان'}),
          Icons.local_fire_department_rounded);
      expect(PlaceDisplay.iconForPlace({'name': 'بەڕێوەبەرایەتی پۆلیسی کەلار', 'category': 'فەرمانگەکان'}),
          Icons.local_police_rounded);
      expect(PlaceDisplay.iconForPlace({'name': 'دوکانی ئەحمەد', 'category': 'بەنزینخانەکان'}),
          Icons.local_gas_station_rounded);
    });

    test('«شوێنی وەرزشی» ئایکۆنی وەرزشە نەک بازاڕ', () {
      expect(PlaceDisplay.icon('شوێنی وەرزشی'), Icons.sports_soccer_rounded);
      expect(PlaceDisplay.icon('بەشێکی نەناسراو'), Icons.storefront_rounded);
    });
  });

  test('دووری: نەزانراو پیشان نادرێت', () {
    expect(PlaceDisplay.distance(99999), isNull);
    expect(PlaceDisplay.distance(null), isNull);
    expect(PlaceDisplay.distance(0.328, kurdishDigits: false), '328 م');
    expect(PlaceDisplay.distance(2.34, kurdishDigits: false), '2.3 کم');
  });
}
