import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/services/services_screen.dart';
import 'package:kalar_guide_new/services/app_control.dart';

void main() {
  tearDown(() => AppControl.state.value = const AppControlState());

  test('هەموو بەشە نوێیەکان دوگمەیان هەیە و بە بنەڕەت کراوەن', () {
    const keys = [
      'news', 'breaking_news', 'fuel_prices', 'currency_prices', 'pharmacy_duty',
      'departments', 'emergency', 'neighborhood_alerts', 'prayer', 'weather',
    ];
    for (final k in keys) {
      expect(AppControlState.featureKeys, contains(k));
      expect(const AppControlState().feature(k), isTrue, reason: k);
    }
    final s = AppControlState.fromRows(const [
      {'key': 'features', 'value': {'pharmacy_duty': false, 'news': false}},
    ]);
    expect(s.feature('pharmacy_duty'), isFalse);
    expect(s.feature('news'), isFalse);
    expect(s.feature('emergency'), isTrue);
  });

  testWidgets('خزمەتگوزارییەکان: بەشی کوژاوە نیشان نادرێت', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ServicesScreen()));
    expect(find.text('دەرمانخانەی ئێشکگر'), findsOneWidget);
    expect(find.text('فەرمانگە و مامەڵەکان'), findsOneWidget);

    AppControl.state.value = AppControlState.fromRows(const [
      {'key': 'features', 'value': {'pharmacy_duty': false, 'departments': false}},
    ]);
    await tester.pump();
    expect(find.text('دەرمانخانەی ئێشکگر'), findsNothing);
    expect(find.text('فەرمانگە و مامەڵەکان'), findsNothing);
    expect(find.text('فریاکەوتن'), findsOneWidget);
  });
}
