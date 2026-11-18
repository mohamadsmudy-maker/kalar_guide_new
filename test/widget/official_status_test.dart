import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/l10n/tr.dart';
import 'package:kalar_guide_new/services/app_control.dart';
import 'package:kalar_guide_new/widgets/official_status_note.dart';

void main() {
  tearDown(() => AppLang.setCode('ku'));

  test('official_status لە app_settings دەخوێنرێتەوە', () {
    expect(AppControlState.fromRows(const []).official, isFalse);
    final on = AppControlState.fromRows(const [
      {'key': 'official_status', 'value': {'official': true, 'org': 'شارەوانیی کەلار'}},
    ]);
    expect(on.official, isTrue);
    expect(on.officialOrg, 'شارەوانیی کەلار');
    // بێ ناوی دامەزراوە فەرمی نییە
    final noOrg = AppControlState.fromRows(const [
      {'key': 'official_status', 'value': {'official': true, 'org': ' '}},
    ]);
    expect(noOrg.official, isFalse);
  });

  testWidgets('دەقی فەرمی و نافەرمی', (tester) async {
    Future<String> textOf(AppControlState s) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: OfficialStatusNote(state: s))));
      return tester.widget<Text>(find.descendant(
              of: find.byKey(const ValueKey('official-status')), matching: find.byType(Text)))
          .data!;
    }

    expect(await textOf(const AppControlState()), contains('فەرمی'));
    expect(await textOf(const AppControlState()), contains('نییە'));
    expect(await textOf(const AppControlState(official: true, officialOrg: 'شارەوانیی کەلار')),
        'ئەمە ئەپی فەرمیی شارەوانیی کەلار ـە.');
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

    AppLang.setCode('en');
    expect(await textOf(const AppControlState(official: true, officialOrg: 'شارەوانیی کەلار')),
        'This is the official app of Kalar Municipality.');
    expect(await textOf(const AppControlState()), startsWith('This is an independent app'));
  });
}
