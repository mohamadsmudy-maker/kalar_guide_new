import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/l10n/tr.dart';
import 'package:kalar_guide_new/utils/place_display.dart';

void main() {
  tearDown(() => AppLang.setCode('ku'));

  test('database text with Arabic letters / ZWNJ / extra spaces still translates', () {
    AppLang.setCode('en');
    expect(tr('بارەگا حزبییەکان'), isNot('بارەگا حزبییەکان'));
    expect(tr(' بارەگا  حزبيیەکان‌ '), tr('بارەگا حزبییەکان'));
    expect(tr('ئیدارەی گەرمیان'), 'Garmiyan Administration');
    expect(tr('هیچ دەقێکی وانییە'), 'هیچ دەقێکی وانییە');
  });

  test('category matching uses category and sub_category, normalized', () {
    expect(PlaceDisplay.inCategory({'category': 'بانک و نوسینگەی دراو '}, 'بانک و نوسینگەی دراو'), isTrue);
    expect(PlaceDisplay.inCategory({'category': 'x', 'sub_category': 'بانك و نوسینگەی دراو'}, 'بانک و نوسینگەی دراو'), isTrue);
    expect(PlaceDisplay.inCategory({'category': 'تەندروستی'}, 'بانک'), isFalse);
    expect(PlaceDisplay.inCategory({'category': 'تەندروستی'}, ''), isFalse);
  });
}
