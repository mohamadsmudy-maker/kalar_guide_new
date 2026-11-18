import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/neighborhood_alert_service.dart';
import 'package:kalar_guide_new/widgets/neighborhoods/neighborhood_alerts_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<(String, bool)> calls;
  setUp(() {
    calls = [];
    SharedPreferences.setMockInitialValues({});
    NeighborhoodAlertService.topicOverride = (topic, on) async => calls.add((topic, on));
  });
  tearDown(() => NeighborhoodAlertService.topicOverride = null);

  Future<void> pump(WidgetTester t, List<NeighborhoodAlert> alerts) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NeighborhoodAlertsCard(neighborhoodId: 2, color: Colors.teal, loader: (_) async => alerts),
      ),
    ));
    await t.pump();
    await t.pump();
  }

  Switch sw(WidgetTester t) => t.widget<Switch>(find.byKey(const ValueKey('nbh-alerts-switch')));

  testWidgets('هەڵبژاردنی گەڕەک → topic + بیرکردنەوە', (t) async {
    await pump(t, const []);
    expect(sw(t).value, isFalse);

    await t.tap(find.byKey(const ValueKey('nbh-alerts-switch')));
    await t.pump();
    await t.pump();
    expect(calls, [('nbh_2', true)]);
    expect(sw(t).value, isTrue);
    expect(await NeighborhoodAlertService.subscribed(), {2});

    await t.tap(find.byKey(const ValueKey('nbh-alerts-switch')));
    await t.pump();
    await t.pump();
    expect(calls.last, ('nbh_2', false));
    expect(await NeighborhoodAlertService.subscribed(), isEmpty);
  });

  testWidgets('ئەگەر Firebase سەرکەوتوو نەبوو، هیچ پاشەکەوت ناکرێت', (t) async {
    NeighborhoodAlertService.topicOverride = (_, __) async => throw Exception('offline');
    await pump(t, const []);
    await t.tap(find.byKey(const ValueKey('nbh-alerts-switch')));
    await t.pump();
    await t.pump();
    expect(sw(t).value, isFalse);
    expect(await NeighborhoodAlertService.subscribed(), isEmpty);
  });

  testWidgets('دوایین ئاگادارییەکان پیشان دەدرێن', (t) async {
    await pump(t, [
      NeighborhoodAlert(id: 1, neighborhoodId: 2, title: 'بڕینی ئاو', body: 'سبەی لە ٩ تا ٢', createdAt: DateTime(2026, 12, 3)),
    ]);
    expect(find.text('بڕینی ئاو'), findsOneWidget);
    expect(find.text('سبەی لە ٩ تا ٢'), findsOneWidget);
  });

  test('ناوی topic لەگەڵ فەنکشنەکەی سێرڤەر یەکە', () {
    expect(NeighborhoodAlertService.topicFor(2), 'nbh_2');
  });
}
