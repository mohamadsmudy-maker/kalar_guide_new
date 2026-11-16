import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/ticker_service.dart';
import 'package:kalar_guide_new/widgets/ticker_banner.dart';

const _long = 'ئەمە دەقێکی زۆر درێژی هەواڵی بەپەلەیە کە لە پانی شاشە درێژترە و دەبێت بە تەواوی ببینرێت نەک ببڕدرێت';

NewsTicker _t(String ku, {String en = ''}) => NewsTicker(
      id: 1, textKu: ku, textAr: '', textEn: en, textFa: '', isActive: true, displayOrder: 0);

Future<void> _pump(WidgetTester tester, List<NewsTicker> tickers) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Column(children: [
        const Spacer(),
        TickerBannerWidget(loader: () async => tickers),
      ]),
    ),
  ));
  await tester.pump();
}

void main() {
  final text = find.byKey(const ValueKey('ticker-text'));

  testWidgets('بێ تووڵی چالاک دەرناکەوێت', (tester) async {
    await _pump(tester, []);
    expect(text, findsNothing);
    expect(tester.getSize(find.byType(TickerBannerWidget)).height, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('دەق لە چەپەوە بۆ ڕاست دەجوڵێت و نابڕدرێت', (tester) async {
    await _pump(tester, [_t(_long), _t('دووەم')]);
    await tester.pump();
    expect(text, findsOneWidget);
    expect(tester.widget<Text>(text).data, contains('دووەم'));

    // دەقەکە لە پانی شاشە درێژترە، واتە نەبڕدراوە
    final screen = tester.getSize(find.byType(Scaffold)).width;
    expect(tester.getSize(text).width, greaterThan(screen));

    await tester.pump(const Duration(seconds: 1));
    final x1 = tester.getTopLeft(text).dx;
    await tester.pump(const Duration(seconds: 2));
    final x2 = tester.getTopLeft(text).dx;
    expect(x2, greaterThan(x1));
    await tester.pumpWidget(const SizedBox());
  });
}
