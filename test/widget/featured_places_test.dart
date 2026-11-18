import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/featured_place_sheet.dart';
import 'package:kalar_guide_new/services/app_control.dart';
import 'package:kalar_guide_new/services/featured_places.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 12);
  Map<String, dynamic> p(String name, [String? until]) => {'id': name, 'name': name, 'featured_until': until};

  tearDown(() => AppControl.state.value = const AppControlState());

  test('تەنها ماوەی داهاتوو پێشنیارکراوە', () {
    expect(FeaturedPlaces.isFeatured(p('a', '2026-12-01T00:00:00Z'), enabled: true, now: now), isTrue);
    expect(FeaturedPlaces.isFeatured(p('b', '2026-11-01T00:00:00Z'), enabled: true, now: now), isFalse);
    expect(FeaturedPlaces.isFeatured(p('c'), enabled: true, now: now), isFalse);
    expect(FeaturedPlaces.isFeatured(p('a', '2026-12-01T00:00:00Z'), enabled: false, now: now), isFalse);
  });

  test('پێشنیارکراوەکان لە سەرەوە، ڕیزی تر وەک خۆی', () {
    final list = [p('a'), p('b', '2026-12-01T00:00:00Z'), p('c'), p('d', '2027-01-01T00:00:00Z'), p('e', '2026-01-01T00:00:00Z')];
    expect(FeaturedPlaces.featuredFirst(list, enabled: true, now: now).map((e) => e['name']),
        ['b', 'd', 'a', 'c', 'e']);
    // تایبەتمەندییەکە کوژاوە → ڕیزەکە ناگۆڕێت
    expect(FeaturedPlaces.featuredFirst(list, enabled: false, now: now).map((e) => e['name']),
        ['a', 'b', 'c', 'd', 'e']);
  });

  test('دوگمەی ناوەندی کۆنترۆڵ (features.featured_places)', () {
    expect(AppControlState.featureKeys, contains('featured_places'));
    AppControl.state.value = AppControlState.fromRows(const [
      {'key': 'features', 'value': {'featured_places': false}},
    ]);
    expect(FeaturedPlaces.enabled, isFalse);
    AppControl.state.value = const AppControlState();
    expect(FeaturedPlaces.enabled, isTrue, reason: 'on by default');
  });

  testWidgets('ئەدمین: ٣٠ ڕۆژ پێشنیارکراو، پاشان لابردن', (tester) async {
    final calls = <int?>[];
    final place = p('شوێن');
    Future<DateTime?> save(Object id, int? days) async {
      calls.add(days);
      return days == null ? null : DateTime.now().add(Duration(days: days));
    }

    Future<void> open() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => showFeaturedPlaceSheet(c, place, save: save),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.byKey(const ValueKey('feature-remove')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('feature-30')));
    await tester.pumpAndSettle();
    expect(calls, [30]);
    expect(FeaturedPlaces.isFeatured(place, enabled: true), isTrue);

    await open();
    await tester.tap(find.byKey(const ValueKey('feature-remove')));
    await tester.pumpAndSettle();
    expect(calls, [30, null]);
    expect(FeaturedPlaces.isFeatured(place, enabled: true), isFalse);
  });
}
