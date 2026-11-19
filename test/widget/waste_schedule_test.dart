import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/admin_waste_schedule.dart';
import 'package:kalar_guide_new/services/waste_schedule_service.dart';
import 'package:kalar_guide_new/widgets/neighborhoods/waste_schedule_card.dart';

void main() {
  // پێنجشەممە ١٩ی نوێمبەری ٢٠٢٦، کاتژمێر ١٠ی بەیانی
  final thu = DateTime(2026, 11, 19, 10);
  const sched = WasteSchedule(
    neighborhoodId: 2,
    neighborhoodName: 'شۆڕش',
    weekdays: [DateTime.saturday, DateTime.monday, DateTime.wednesday],
    timeText: '07:00',
  );

  test('ڕۆژی داهاتوو', () {
    expect(sched.nextCollection(thu), DateTime(2026, 11, 21)); // شەممە
    final mon = DateTime(2026, 11, 23, 6);
    expect(sched.nextCollection(mon), DateTime(2026, 11, 23)); // ئەمڕۆ
    expect(const WasteSchedule(neighborhoodId: 1).nextCollection(thu), isNull);
  });

  test('ئاگادارکردنەوە: شەوی پێش هەر ڕۆژێک، کاتژمێر ٨', () {
    final t = sched.reminderTimes(thu, weeks: 1);
    expect(t, [
      DateTime(2026, 11, 20, 20), // هەینی شەو ← شەممە
      DateTime(2026, 11, 22, 20), // یەکشەممە شەو ← دووشەممە
      DateTime(2026, 11, 24, 20), // سێشەممە شەو ← چوارشەممە
    ]);
    // ئەگەر کاتی ئەمشەو تێپەڕیبێت، ناخرێتە لیستەوە
    final lateFri = DateTime(2026, 11, 20, 21);
    expect(sched.reminderTimes(lateFri, weeks: 1).first, DateTime(2026, 11, 22, 20));
  });

  test('fromMap: ڕۆژەکان ڕیز دەکرێن', () {
    final s = WasteSchedule.fromMap(const {'neighborhood_id': 5, 'weekdays': [6, 1, 3], 'time_text': null});
    expect(s.weekdays, [1, 3, 6]);
    expect(s.timeText, '');
  });

  testWidgets('کارتی گەڕەک: ڕۆژەکان، داهاتوو، و ئاگادارکردنەوە', (tester) async {
    int? subscribed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WasteScheduleCard(
          neighborhoodId: 2,
          neighborhoodName: 'شۆڕش',
          loader: (_) async => sched,
          subscription: () async => null,
          onSubscribe: (id) async => subscribed = id,
          clock: () => DateTime(2026, 11, 20, 10), // هەینی
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('شەممە'), findsOneWidget);
    expect(find.text('دووشەممە'), findsOneWidget);
    expect(find.text('داهاتوو: سبەی'), findsOneWidget);
    expect(find.text('کات: 07:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('waste-remind')));
    await tester.pumpAndSettle();
    expect(subscribed, 2);
  });

  testWidgets('کارت بێ خشتە دەرناکەوێت', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WasteScheduleCard(
          neighborhoodId: 9,
          neighborhoodName: 'x',
          loader: (_) async => null,
          subscription: () async => null,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('waste-schedule-card')), findsNothing);
  });

  testWidgets('ئەدمین: هەڵبژاردنی ڕۆژ و پاشەکەوتکردن', (tester) async {
    WasteSchedule? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WasteScheduleSheet(
          initial: const WasteSchedule(neighborhoodId: 3, weekdays: [DateTime.sunday]),
          neighborhoodName: 'ئازادی',
          saver: (s) async => saved = s,
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('day-6'))); // شەممە
    await tester.tap(find.byKey(const ValueKey('day-7'))); // یەکشەممە لابردن
    await tester.enterText(find.byType(TextField).first, '6:00 - 9:00');
    await tester.tap(find.byKey(const ValueKey('waste-save')));
    await tester.pumpAndSettle();
    expect(saved!.weekdays, [DateTime.saturday]);
    expect(saved!.timeText, '6:00 - 9:00');
    expect(saved!.neighborhoodName, 'ئازادی');
  });
}
