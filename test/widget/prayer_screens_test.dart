// test/widget/prayer_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/admin_prayer_times.dart';
import 'package:kalar_guide_new/screens/prayer/prayer_month_share.dart';
import 'package:kalar_guide_new/screens/prayer/prayer_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: w));
    await tester.pumpAndSettle();
  }

  testWidgets('خشتەی مانگ: ٣٠ ڕۆژی تشرینی دووەم و کاتی فەرمی', (tester) async {
    await pump(tester, const PrayerMonthSharePage(year: 2026, month: 11, monthName: 'تشرینی دووەم'));
    expect(find.text('تشرینی دووەم 2026'), findsOneWidget);
    expect(find.textContaining('هەینی'), findsNWidgets(4));
    expect(find.text('5:04'), findsWidgets); // ئێوارەی ٧ی مانگ
    expect(find.text('هاوبەشکردن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ڕێکخستنی نوێژ: ژمارەی کوردی دەگۆڕێت و پاشەکەوت دەکرێت', (tester) async {
    await pump(tester, const PrayerSettingsScreen());
    expect(find.text('بیرخستنەوەی هەینی'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ژمارەی کوردی'), 200);
    expect(find.text('5:04 د.ن'), findsOneWidget);
    // ژمارەی کوردی دوایین Switch ـە
    final sw = find.byType(Switch).last;
    await tester.ensureVisible(sw);
    await tester.pumpAndSettle();
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(find.text('٥:٠٤ د.ن'), findsOneWidget);
    final p = await SharedPreferences.getInstance();
    expect(p.getBool('prayer_kurdish_digits'), isTrue);
  });

  testWidgets('ئەدمین: خشتەی مانگ پیشان دەدات بێ Supabase', (tester) async {
    await pump(tester, const AdminPrayerTimesScreen());
    expect(find.text('کاتەکانی نوێژ'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
