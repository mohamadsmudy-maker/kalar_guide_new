import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/l10n/tr.dart';
import 'package:kalar_guide_new/services/ticker_service.dart';
import 'package:kalar_guide_new/widgets/ticker_banner.dart';

const _long =
    'ئەمە دەقێکی زۆر درێژی هەواڵی بەپەلەیە کە لە پانی شاشە درێژترە و دەبێت بە تەواوی ببینرێت نەک ببڕدرێت';

NewsTicker _t(String ku, {String en = ''}) => NewsTicker(
    id: 1, textKu: ku, textAr: '', textEn: en, textFa: '', isActive: true, displayOrder: 0);

Future<void> _pump(WidgetTester tester, List<NewsTicker> tickers,
    {bool autoDialog = false}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Column(children: [
        const Spacer(),
        TickerBannerWidget(loader: () async => tickers, autoDialog: autoDialog),
      ]),
    ),
  ));
  await tester.pump();
}

void main() {
  final text = find.byKey(const ValueKey('ticker-text'));
  tearDown(() => AppLang.setCode('ku'));

  testWidgets('بێ تووڵی چالاک دەرناکەوێت', (tester) async {
    await _pump(tester, []);
    expect(text, findsNothing);
    expect(tester.getSize(find.byType(TickerBannerWidget)).height, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('کوردی: چەپ → ڕاست و نابڕدرێت', (tester) async {
    AppLang.setCode('ku');
    await _pump(tester, [_t(_long), _t('دووەم')]);
    await tester.pump();
    expect(tester.widget<Text>(text).data, contains('دووەم'));

    final screen = tester.getSize(find.byType(Scaffold)).width;
    expect(tester.getSize(text).width, greaterThan(screen)); // نەبڕدراوە

    await tester.pump(const Duration(seconds: 1));
    final x1 = tester.getTopLeft(text).dx;
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(text).dx, greaterThan(x1)); // بۆ ڕاست
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ئینگلیزی: ڕاست → چەپ', (tester) async {
    AppLang.setCode('en');
    await _pump(tester, [_t(_long, en: 'This is a very long breaking news item that overflows the screen width')]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final x1 = tester.getTopLeft(text).dx;
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(text).dx, lessThan(x1)); // بۆ چەپ
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('کرتە → دایەلۆگ دەکرێتەوە', (tester) async {
    await _pump(tester, [_t('هەواڵی گرنگ')]);
    await tester.tap(find.byType(TickerBannerWidget));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('هەواڵی گرنگ'), findsWidgets);
    await tester.tap(find.text('تێگەیشتم'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(Dialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
