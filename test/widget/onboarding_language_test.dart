import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/config/settings_provider.dart';
import 'package:kalar_guide_new/l10n/tr.dart';
import 'package:kalar_guide_new/screens/onboarding/onboarding_screen.dart';
import 'package:kalar_guide_new/services/prayer/prayer_scheduler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  // وەک ئەپ: ڕێکخستنەکان پێش شاشەکە بار دەکرێن
  final settings = SettingsProvider();
  await tester.pump();
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: settings,
    child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  tearDown(() => AppLang.setCode('ku'));

  test('ڕیزی زمانەکان: کوردی، عەرەبی، فارسی، ئینگلیزی', () {
    expect(SettingsProvider.availableLanguages.map((l) => l.id),
        ['ku', 'ar', 'fa', 'en']);
    expect(AppLang.supported, ['ku', 'ar', 'fa', 'en']);
  });

  test('بانگ بە بنەڕەت ناچالاکە', () {
    expect(PrayerScheduler.enabledByDefault, isFalse);
  });

  testWidgets('یەکەم کردنەوە: داوای زمان دەکات بە ڕیزی دروست', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester);

    final ys = [
      for (final id in ['ku', 'ar', 'fa', 'en'])
        tester.getTopLeft(find.byKey(ValueKey('lang-$id'))).dy,
    ];
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]));
    }

    await tester.tap(find.byKey(const ValueKey('lang-en')));
    await tester.pump();
    expect(AppLang.code, 'en');
    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lang-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('lang-continue')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language_id'), 'en');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ئەگەر زمان پێشتر هەڵبژێردرابوو، دووبارە ناپرسێت', (tester) async {
    SharedPreferences.setMockInitialValues({'language_id': 'ar'});
    await _pump(tester);
    expect(find.byKey(const ValueKey('lang-ku')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
