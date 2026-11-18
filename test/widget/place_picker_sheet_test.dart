import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/place_picker_sheet.dart';
import 'package:kalar_guide_new/services/pharmacy_duty_service.dart';

void main() {
  test('هەموو شێوازەکانی نووسینی دەرمانخانە دەگرێتەوە', () {
    bool hit(String s) => PharmacyDutyService.pharmacyWords.any((w) => s.toLowerCase().contains(w));
    expect(hit('دەرمانخانەی شیفا'), isTrue);
    expect(hit('دەرمانگەی ژیان'), isTrue);
    expect(hit('ده‌رمانخانه‌ی ئازادی'), isTrue);
    expect(hit('دهرمانخانه'), isTrue);
    expect(hit('صيدلية الشفاء'), isTrue);
    expect(hit('Shifa Pharmacy'), isTrue);
    expect(hit('بەنزینخانەی ڕاما'), isFalse);
  });

  testWidgets('بەتاڵ → دەرمانخانەکان؛ نووسین → گەڕان؛ کرتە → هەڵبژاردن', (t) async {
    final queries = <String>[];
    Future<List<Map<String, dynamic>>> search(String q) async {
      queries.add(q);
      return q.isEmpty
          ? [{'id': 1, 'name': 'دەرمانخانەی شیفا'}]
          : [{'id': 9, 'name': 'ژیان', 'address': 'شەقامی سەرەکی'}];
    }

    Map<String, dynamic>? picked;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => picked = await PlacePickerSheet.show(c, search: search, color: Colors.green),
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('دەرمانخانەی شیفا'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'ژیان');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(queries, ['', 'ژیان']);
    expect(find.text('شەقامی سەرەکی'), findsOneWidget);

    await t.tap(find.text('ژیان').last);
    await t.pumpAndSettle();
    expect(picked?['id'], 9);
  });

  testWidgets('هیچ دەرمانخانەیەک نییە → ڕێنمایی پیشان دەدرێت', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => PlacePickerSheet.show(c, search: (_) async => [], color: Colors.green),
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.textContaining('هیچ دەرمانخانەیەک لە شوێنەکاندا نەدۆزرایەوە'), findsOneWidget);
  });
}
