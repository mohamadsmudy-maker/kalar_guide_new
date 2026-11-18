import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/pharmacy/on_duty_pharmacy_screen.dart';
import 'package:kalar_guide_new/services/pharmacy_duty_service.dart';

void main() {
  group('dutyNight', () {
    test('پێش کاتژمێر ٨ی بەیانی هێشتا شەوی دوێنێیە', () {
      expect(PharmacyDutyService.dutyNight(DateTime(2026, 12, 1, 3)), DateTime(2026, 11, 30));
      expect(PharmacyDutyService.dutyNight(DateTime(2026, 12, 1, 7, 59)), DateTime(2026, 11, 30));
    });
    test('لە ٨ی بەیانی بەدواوە شەوی ئەمڕۆیە', () {
      expect(PharmacyDutyService.dutyNight(DateTime(2026, 12, 1, 8)), DateTime(2026, 12, 1));
      expect(PharmacyDutyService.dutyNight(DateTime(2026, 12, 1, 23)), DateTime(2026, 12, 1));
    });
    test('سەری ساڵ', () {
      expect(PharmacyDutyService.dutyNight(DateTime(2027, 1, 1, 2)), DateTime(2026, 12, 31));
      expect(PharmacyDutyService.dateKey(DateTime(2026, 3, 5)), '2026-03-05');
    });
  });

  PharmacyDuty duty(int id, DateTime d, String name, {String phone = ''}) =>
      PharmacyDuty(id: id, dutyDate: d, name: name, phone: phone);

  Future<void> pump(WidgetTester t, List<PharmacyDuty> items, DateTime now) async {
    await t.pumpWidget(MaterialApp(
      home: OnDutyPharmacyScreen(loader: (_, __) async => items, clock: () => now),
    ));
    await t.pump();
  }

  testWidgets('ئەمشەو و ڕۆژانی داهاتوو جیا دەکرێنەوە', (t) async {
    final now = DateTime(2026, 12, 1, 22);
    await pump(t, [
      duty(1, DateTime(2026, 12, 1), 'دەرمانخانەی شیفا', phone: '07701111111'),
      duty(2, DateTime(2026, 12, 2), 'دەرمانخانەی ژیان'),
    ], now);
    expect(find.text('دەرمانخانەی شیفا'), findsOneWidget);
    expect(find.text('ڕۆژانی داهاتوو'), findsOneWidget);
    expect(find.text('دەرمانخانەی ژیان'), findsOneWidget);
    expect(find.text('پەیوەندی'), findsOneWidget);
    expect(find.text('هێشتا دەرمانخانەی ئێشکگری ئەمشەو دیاری نەکراوە'), findsNothing);
  });

  testWidgets('کاتژمێر ٣ی بەیانی: ئێشکگری دوێنێ شەو پیشان دەدرێت', (t) async {
    await pump(t, [duty(1, DateTime(2026, 11, 30), 'دەرمانخانەی شیفا')], DateTime(2026, 12, 1, 3));
    expect(find.text('دەرمانخانەی شیفا'), findsOneWidget);
    expect(find.text('ڕۆژانی داهاتوو'), findsNothing);
  });

  testWidgets('ئەگەر دیاری نەکرابێت پەیامێکی ڕوون پیشان دەدرێت', (t) async {
    await pump(t, const [], DateTime(2026, 12, 1, 22));
    expect(find.text('هێشتا دەرمانخانەی ئێشکگری ئەمشەو دیاری نەکراوە'), findsOneWidget);
  });
}
