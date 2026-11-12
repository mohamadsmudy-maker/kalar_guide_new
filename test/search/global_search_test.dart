import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/search/global_search_screen.dart';
import 'package:kalar_guide_new/services/search/global_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

SearchItem it(SearchKind k, String title, {String sub = '', String kw = ''}) =>
    SearchItem(kind: k, title: title, subtitle: sub, keywords: kw);

void main() {
  final items = [
    it(SearchKind.place, 'بەڕێوەبەرایەتی هاتوچۆی گەرمیان', sub: 'فەرمانگە'),
    it(SearchKind.place, 'چێشتخانەی کەلار', kw: 'خواردن کباب'),
    it(SearchKind.transaction, 'دەرهێنانی مۆڵەتی شۆفێری',
        sub: 'هاتوچۆ', kw: 'کارتی نیشتمانی'),
    it(SearchKind.neighborhood, 'کەلاری کۆن'),
    it(SearchKind.emergency, 'پۆلیس', sub: '104'),
  ];

  group('GlobalSearch', () {
    test('نووسینی عەرەبی و کوردی یەکسانن (ك/ک، ي/ی، ه/ە)', () {
      expect(GlobalSearch.search(items, 'كەلار').map((e) => e.title),
          containsAll(['چێشتخانەی کەلار', 'کەلاری کۆن']));
      expect(GlobalSearch.normalize('كەلاري'), GlobalSearch.normalize('کەلاری'));
    });

    test('ژمارەی کوردی و ئینگلیزی', () {
      expect(GlobalSearch.search(items, '١٠٤').single.title, 'پۆلیس');
    });

    test('دەستپێک پێش ناوەڕاست دێت', () {
      final r = GlobalSearch.search(items, 'کەلار');
      expect(r.first.title, 'کەلاری کۆن');
    });

    test('هەموو وشەکان پێویستن، بە هەر ڕیزێک', () {
      expect(GlobalSearch.search(items, 'شۆفێری مۆڵەت').single.kind,
          SearchKind.transaction);
      expect(GlobalSearch.search(items, 'مۆڵەت فڕۆکە'), isEmpty);
    });

    test('گەڕان لە وشە شاراوەکان و فلتەری جۆر', () {
      expect(GlobalSearch.search(items, 'کباب').single.title, 'چێشتخانەی کەلار');
      expect(
          GlobalSearch.search(items, 'کەلار', only: SearchKind.neighborhood)
              .length,
          1);
      expect(GlobalSearch.search(items, '  '), isEmpty);
    });

    test('ژمارەی ئەنجام بەپێی جۆر', () {
      final c = GlobalSearch.counts(GlobalSearch.search(items, 'کەلار'));
      expect(c[SearchKind.place], 1);
      expect(c[SearchKind.neighborhood], 1);
    });
  });

  testWidgets('شاشەی گەڕان: ئەنجام، چیپ، هیچ ئەنجام، گەڕانی پێشوو', (t) async {
    SharedPreferences.setMockInitialValues({
      'global_search_recent': ['مۆڵەت'],
    });
    await t.pumpWidget(MaterialApp(
      home: GlobalSearchScreen(
        loader: () async => items,
        newsSearch: (q) async =>
            [it(SearchKind.news, 'هەواڵی $q')],
      ),
    ));
    await t.pumpAndSettle();

    // پێش نووسین: گەڕانی پێشوو و بەشەکان
    expect(find.text('مۆڵەت'), findsOneWidget);
    expect(find.text('کاتەکانی نوێژ'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'کەلار');
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    expect(find.text('گەڕەکان'), findsWidgets);
    expect(find.text('هەواڵی کەلار'), findsOneWidget);
    expect(find.textContaining('هەموو  '), findsOneWidget);

    await t.enterText(find.byType(TextField), 'زززز');
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    // هەواڵی ساختە هەمیشە دەگەڕێتەوە، بۆیە تەنها ئەو دەمێنێت
    expect(find.text('هەواڵی زززز'), findsOneWidget);
    expect(find.text('کەلاری کۆن'), findsNothing);

    // بەشی ئەپ بە وشەی شاراوە
    await t.enterText(find.byType(TextField), 'بەنزین');
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    expect(find.text('نرخی سووتەمەنی'), findsOneWidget);
  });
}
