import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/opening_hours.dart';
import 'package:kalar_guide_new/widgets/opening_hours_widgets.dart';

Widget host(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

void main() {
  final hours = OpeningHours.fromJson({
    'days': {
      for (final k in ['sat', 'sun', 'mon', 'tue', 'wed', 'thu']) k: {'open': '08:00', 'close': '21:00'},
      'fri': null,
    },
  })!;
  final noon = DateTime(2026, 11, 14, 12); // شەممە
  final night = DateTime(2026, 11, 14, 23);

  test('دەقی دۆخ', () {
    expect(openStatusText(hours, noon), contains('کراوەیە'));
    expect(openStatusText(hours, night), contains('داخراوە'));
    expect(openStatusText(hours, night), contains('سبەینێ'));
    expect(openStatusText(const OpeningHours(is24h: true), noon), contains('٢٤'));
  });

  testWidgets('OpenBadge: کراو / داخراو / بێ کات = هیچ', (t) async {
    await t.pumpWidget(host(OpenBadge(hours: hours, now: noon)));
    expect(find.text('کراوە'), findsOneWidget);
    await t.pumpWidget(host(OpenBadge(hours: hours, now: night)));
    expect(find.text('داخراو'), findsOneWidget);
    await t.pumpWidget(host(const OpenBadge(hours: null)));
    expect(find.text('کراوە'), findsNothing);
    expect(find.text('داخراو'), findsNothing);
  });

  testWidgets('OpeningHoursView: لیستی هەفتە دەکرێتەوە و هەینی داخراوە', (t) async {
    await t.pumpWidget(host(OpeningHoursView(hours: hours, now: noon)));
    expect(find.text('شەممە'), findsNothing); // داخراوە تا بکرێتەوە
    await t.tap(find.byType(ExpansionTile));
    await t.pumpAndSettle();
    expect(find.text('شەممە'), findsOneWidget);
    expect(find.text('هەینی'), findsOneWidget);
    expect(find.text('داخراوە'), findsOneWidget); // تەنها هەینی
  });

  testWidgets('OpeningHoursEditor: ڕۆژ داخستن، ٢٤ سەعات، و null ئەگەر هیچ نەما', (t) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    OpeningHours? last = hours;
    await t.pumpWidget(host(OpeningHoursEditor(initial: hours, onChanged: (h) => last = h)));
    // هەینی داخراوە، یەکشەممە بکرێتەوە → چالاک دەبێت بە ٠٨-٢١
    final switches = find.byType(Switch);
    await t.tap(switches.at(2)); // sun → داخستن (٠ = ٢٤ سەعات، ١ = شەممە)
    await t.pump();
    expect(last!.days['sun'], isNull);
    await t.tap(switches.at(2)); // دووبارە کردنەوە
    await t.pump();
    expect(last!.days['sun'], const DayHours('08:00', '21:00'));

    // ٢٤ سەعات
    await t.tap(find.widgetWithText(SwitchListTile, '٢٤ سەعات کراوەیە'));
    await t.pump();
    expect(last!.is24h, isTrue);
  });
}
