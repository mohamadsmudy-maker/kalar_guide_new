import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/widgets/stale_prices_banner.dart';

void main() {
  final now = DateTime(2026, 11, 21, 12);

  testWidgets('warns when prices are old', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StalePricesBanner(
          now: now,
          loader: () async => (now.subtract(const Duration(days: 14)), now.subtract(const Duration(hours: 2))),
        ),
      ),
    ));
    await t.pump();
    expect(find.byKey(const ValueKey('stale-prices')), findsOneWidget);
    expect(find.textContaining('سووتەمەنی'), findsWidgets);
    expect(find.textContaining('دراو:'), findsNothing);
  });

  testWidgets('hidden when everything is fresh', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StalePricesBanner(now: now, loader: () async => (now, now)),
      ),
    ));
    await t.pump();
    expect(find.byKey(const ValueKey('stale-prices')), findsNothing);
  });
}
