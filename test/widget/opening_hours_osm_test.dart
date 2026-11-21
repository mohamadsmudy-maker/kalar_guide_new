import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/opening_hours.dart';
import 'package:kalar_guide_new/widgets/opening_hours_widgets.dart';

void main() {
  group('OpeningHours.fromOsm', () {
    test('24/7', () => expect(OpeningHours.fromOsm('24/7')!.is24h, isTrue));

    test('هەموو ڕۆژێک', () {
      final h = OpeningHours.fromOsm('Mo-Su 08:00-22:00')!;
      for (final k in OpeningHours.dayKeys) {
        expect(h.days[k]?.open, '08:00');
        expect(h.days[k]?.close, '22:00');
      }
    });

    test('شەممە تا پێنجشەممە، هەینی داخراو', () {
      final h = OpeningHours.fromOsm('Sa-Th 8:30-14:00; Fr off')!;
      expect(h.days['sat']?.open, '08:30');
      expect(h.days['thu']?.close, '14:00');
      expect(h.days['fri'], isNull);
    });

    test('چەند ماوە لە ڕۆژێکدا و لیستی ڕۆژ', () {
      final h = OpeningHours.fromOsm('Mo,We 09:00-12:00,16:00-21:00')!;
      expect(h.days['mon']?.open, '09:00');
      expect(h.days['mon']?.close, '21:00');
      expect(h.days['tue'], isNull);
      expect(h.days['wed']?.close, '21:00');
    });

    test('بێ ڕۆژ = هەموو ڕۆژێک؛ ٢٤:٠٠ = نیوەشەو', () {
      final h = OpeningHours.fromOsm('10:00-24:00')!;
      expect(h.days['fri']?.close, '00:00');
      expect(h.days['fri']!.crossesMidnight, isTrue);
    });

    test('نەناسراو → null', () {
      expect(OpeningHours.fromOsm(null), isNull);
      expect(OpeningHours.fromOsm(''), isNull);
      expect(OpeningHours.fromOsm('sunrise-sunset'), isNull);
    });
  });

  testWidgets('شێوە ئامادەکان ڕۆژەکان پڕ دەکەنەوە', (tester) async {
    OpeningHours? out;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: OpeningHoursEditor(onChanged: (h) => out = h)),
      ),
    ));
    expect(find.text('دیاری نەکراوە'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hours-week')));
    await tester.pump();
    expect(out!.days['sat']?.open, '08:00');
    expect(out!.days['fri'], isNull);
    expect(find.text('٦ ڕۆژ کراوەیە'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hours-office')));
    await tester.pump();
    expect(out!.days['sun']?.close, '14:00');
    expect(out!.days['sat'], isNull);

    await tester.tap(find.byKey(const ValueKey('hours-24h')));
    await tester.pump();
    expect(out!.is24h, isTrue);

    await tester.tap(find.byKey(const ValueKey('hours-clear')));
    await tester.pump();
    expect(out, isNull);
  });
}
