import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/admin_sponsored_slides.dart';
import 'package:kalar_guide_new/services/app_control.dart';
import 'package:kalar_guide_new/services/sponsored_slides_service.dart';
import 'package:kalar_guide_new/widgets/carousels/sponsored_slide_card.dart';

SponsoredSlide ad(int id, {String type = 'phone', String value = '07701234567', bool active = true,
        DateTime? start, DateTime? end}) =>
    SponsoredSlide(
      id: id,
      title: 'ڕیکلام $id',
      imageUrl: '',
      actionType: type,
      actionValue: value,
      startsOn: start ?? DateTime(2026, 11, 1),
      endsOn: end ?? DateTime(2026, 11, 30),
      isActive: active,
    );

void main() {
  tearDown(() => AppControl.state.value = const AppControlState());
  final now = DateTime(2026, 11, 19, 12);

  test('ماوە و چالاکی', () {
    expect(ad(1).isLive(now), isTrue);
    expect(ad(2, active: false).isLive(now), isFalse);
    expect(ad(3, end: DateTime(2026, 11, 18)).isLive(now), isFalse);
    expect(ad(4, start: DateTime(2026, 11, 20)).isLive(now), isFalse);
    expect(ad(5, start: DateTime(2026, 11, 19), end: DateTime(2026, 11, 19)).isLive(now), isTrue);
    expect(sponsoredStatus(ad(3, end: DateTime(2026, 11, 18)), now), 'تەواو بووە');
    expect(sponsoredStatus(ad(1), now), 'چالاکە');
  });

  test('تێکەڵکردن: دوای هەر ٢ هەواڵ یەک ڕیکلام، زۆرترین ٣', () {
    final news = [for (var i = 1; i <= 5; i++) {'id': 'n$i'}];
    final out = SponsoredSlidesService.interleave(news, [ad(1), ad(2), ad(3), ad(4)]);
    expect(out.map((e) => e['id']), ['n1', 'n2', 'ad-1', 'n3', 'n4', 'ad-2', 'n5', 'ad-3']);
    expect(SponsoredSlidesService.interleave(news, const []), news);
    expect(SponsoredSlidesService.interleave(const [], [ad(7)]).single['id'], 'ad-7');
  });

  test('لینکی دوگمە', () {
    expect(SponsoredSlidesService.actionUri(ad(1)).toString(), 'tel:07701234567');
    expect(SponsoredSlidesService.actionUri(ad(1, type: 'whatsapp')).toString(), 'https://wa.me/9647701234567');
    expect(SponsoredSlidesService.actionUri(ad(1, type: 'url', value: 'facebook.com/x')).toString(),
        'https://facebook.com/x');
    expect(SponsoredSlidesService.actionUri(ad(1, type: 'none', value: '')), isNull);
  });

  test('دوگمەی ناوەندی کۆنترۆڵ', () async {
    expect(AppControlState.featureKeys, contains('sponsored_slides'));
    AppControl.state.value = AppControlState.fromRows(const [
      {'key': 'features', 'value': {'sponsored_slides': false}},
    ]);
    expect(SponsoredSlidesService.enabled, isFalse);
    expect(await SponsoredSlidesService.live(), isEmpty);
  });

  testWidgets('کارتی ڕیکلام: نیشانەی «ڕیکلام» و دوگمە', (tester) async {
    SponsoredSlide? opened;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 250,
          child: SponsoredSlideCard(slide: ad(9, type: 'whatsapp'), onOpen: (s) => opened = s),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('ad-label')), findsOneWidget);
    expect(find.text('ڕیکلام'), findsOneWidget);
    expect(find.text('واتسئاپ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ad-9')));
    expect(opened?.id, 9);
  });

  test('هەڵبژاردنی شوێن/هەواڵ خانەکان پڕ دەکاتەوە', () {
    final p = SponsoredSourcePicker.fill('place', {'id': 12, 'name': 'ئاریان', 'address': 'ئەندازیاران', 'image': 'https://x/a.jpg'});
    expect([p.id, p.title, p.subtitle, p.image], ['12', 'ئاریان', 'ئەندازیاران', 'https://x/a.jpg']);
    final n = SponsoredSourcePicker.fill('news', {'id': 5, 'title': 'هەواڵ', 'images': ['https://x/n.jpg', 'https://x/m.jpg']});
    expect([n.id, n.title, n.image], ['5', 'هەواڵ', 'https://x/n.jpg']);
    final s = SponsoredSourcePicker.fill('news', {'id': 6, 'title': 't', 'images': '["https://x/s.jpg","https://x/t.jpg"]'});
    expect(s.image, 'https://x/s.jpg');
    expect(SponsoredSlide.actionLabel('news'), 'خوێندنەوە');
    expect(SponsoredSlide.customActionTypes, isNot(contains('place')));
  });

  testWidgets('لیستی هەڵبژاردن: گەڕان و هەڵبژاردن', (tester) async {
    final queries = <String>[];
    Map<String, dynamic>? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () async {
              picked = await showModalBottomSheet<Map<String, dynamic>>(
                context: c,
                isScrollControlled: true,
                builder: (_) => SponsoredSourcePicker(
                  kind: 'place',
                  loader: (q) async {
                    queries.add(q);
                    return [
                      {'id': 1, 'name': 'ئاریان', 'address': 'کەلار', 'image': ''},
                      {'id': 2, 'name': 'ڕزگاری', 'address': 'جادە', 'image': ''},
                    ].where((r) => q.isEmpty || '${r['name']}'.contains(q)).toList();
                  },
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('source-1')), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ڕزگ');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('source-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('source-2')));
    await tester.pumpAndSettle();
    expect(picked?['id'], 2);
    expect(queries, ['', 'ڕزگ']);
  });
}
