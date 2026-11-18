import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/translate_languages_dialog.dart';

void main() {
  Future<Set<String>?> open(WidgetTester t, Set<String> filled, Future<void> Function() act) async {
    Set<String>? result;
    var done = false;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async {
            result = await pickTranslateLanguages(c, filled: filled);
            done = true;
          },
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await act();
    await t.pumpAndSettle();
    expect(done, isTrue);
    return result;
  }

  bool checked(WidgetTester t, String l) =>
      t.widget<CheckboxListTile>(find.byKey(ValueKey('lang-$l'))).value!;

  testWidgets('بە شێوەی بنەڕەت تەنها زمانە بەتاڵەکان هەڵبژێردراون', (t) async {
    final r = await open(t, {'en'}, () async {
      expect(checked(t, 'ar'), isTrue);
      expect(checked(t, 'en'), isFalse);
      expect(checked(t, 'fa'), isTrue);
      await t.tap(find.text('وەرگێڕان'));
    });
    expect(r, {'ar', 'fa'});
  });

  testWidgets('تەنها یەک زمان: فارسی', (t) async {
    final r = await open(t, {}, () async {
      await t.tap(find.byKey(const ValueKey('lang-ar')));
      await t.tap(find.byKey(const ValueKey('lang-en')));
      await t.pump();
      await t.tap(find.text('وەرگێڕان'));
    });
    expect(r, {'fa'});
  });

  testWidgets('دووبارە وەرگێڕانی زمانێکی پڕ ئاگاداری پیشان دەدات', (t) async {
    await open(t, {'ar', 'en', 'fa'}, () async {
      expect(find.text('دەقی ئێستای ئەو زمانانە دەگۆڕدرێت.'), findsNothing);
      await t.tap(find.byKey(const ValueKey('lang-en')));
      await t.pump();
      expect(find.text('دەقی ئێستای ئەو زمانانە دەگۆڕدرێت.'), findsOneWidget);
      await t.tap(find.text('پاشگەزبوونەوە'));
    });
  });
}
