import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/l10n/tr.dart';
import 'package:kalar_guide_new/widgets/live_badge.dart';

void main() {
  final now = DateTime(2026, 11, 21, 12);

  test('fresh only within 24h', () {
    expect(LiveBadge.isFresh(now.subtract(const Duration(hours: 3)), now: now), isTrue);
    expect(LiveBadge.isFresh(now.subtract(const Duration(days: 14)), now: now), isFalse);
    expect(LiveBadge.isFresh(null, now: now), isFalse);
  });

  testWidgets('stale prices are not labelled live', (t) async {
    await t.pumpWidget(MaterialApp(
      home: LiveBadge(updated: now.subtract(const Duration(days: 14)), now: now),
    ));
    expect(find.byKey(const ValueKey('live-stale')), findsOneWidget);
    expect(find.text('ڕاستەوخۆ'), findsNothing);
  });

  test('decimal keeps its separator in RTL', () {
    expect(AppLang.localDecimal('0.46', 'ku'), '٠٫٤٦');
    expect(AppLang.localDecimal('0.46', 'en'), '0.46');
  });

  test('trf localizes numbers', () {
    expect(trf('{0} شوێن', [12]).contains('12'), AppLang.code == 'en');
  });
}
