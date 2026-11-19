import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/cache_service.dart';
import 'package:kalar_guide_new/services/network_status.dart';
import 'package:kalar_guide_new/services/pharmacy_duty_service.dart';
import 'package:kalar_guide_new/widgets/offline_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fetchList: بێ ئینتەرنێت دوایین لیست دەگەڕێنێتەوە', () async {
    await CacheService.clear();
    final first = await CacheService.fetchList('t_list', () async => [{'id': 1}]);
    expect(first, [{'id': 1}]);
    final offline = await CacheService.fetchList(
        't_list', () async => throw const SocketException('offline'));
    expect(offline, [{'id': 1}]);
    expect(
      () => CacheService.fetchList('never', () async => throw const SocketException('offline')),
      throwsA(isA<SocketException>()),
    );
  });

  test('بێ تۆڕ: یەکسەر داتای هەڵگیراو، بێ چاوەڕوانی سێرڤەر', () async {
    await CacheService.clear();
    await CacheService.fetchList('t_fast', () async => [{'id': 7}]);
    NetworkStatus.offlineForTest = true;
    addTearDown(() => NetworkStatus.offlineForTest = false);
    var called = false;
    final sw = Stopwatch()..start();
    final r = await CacheService.fetchList('t_fast', () async {
      called = true;
      await Future<void>.delayed(const Duration(seconds: 30)); // سێرڤەری وەستاو
      return [];
    });
    expect(r, [{'id': 7}]);
    expect(called, isFalse, reason: 'the server is not even tried');
    expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('سێرڤەری وەستاو (WiFi بێ ئینتەرنێت): دوای کاتی دیاریکراو داتای هەڵگیراو', () async {
    await CacheService.clear();
    await CacheService.fetchList('t_slow', () async => [{'id': 1}]);
    final old = CacheService.networkTimeout;
    CacheService.networkTimeout = const Duration(milliseconds: 200);
    addTearDown(() => CacheService.networkTimeout = old);
    final r = await CacheService.fetchList(
        't_slow', () => Completer<List<Map<String, dynamic>>>().future);
    expect(r, [{'id': 1}]);
  });

  test('fetchJson: Map و null', () async {
    await CacheService.clear();
    await CacheService.fetchJson('t_map', () async => {'value': {'normal': 1000}});
    final m = await CacheService.fetchJson('t_map', () async => throw const SocketException('x'));
    expect(m['value']['normal'], 1000);
    expect(await CacheService.fetchJson('t_null', () async => null), isNull);
  });

  test('دەرمانخانە: تەنها شەوەکانی ناو ماوەکە', () {
    PharmacyDuty d(String date) =>
        PharmacyDuty.fromMap({'id': 1, 'duty_date': date, 'name': date});
    final all = [d('2026-11-17'), d('2026-11-18'), d('2026-11-20'), d('2026-11-25')];
    final r = PharmacyDutyService.inRange(all, DateTime(2026, 11, 18), DateTime(2026, 11, 24));
    expect(r.map((e) => e.name), ['2026-11-18', '2026-11-20']);
  });

  testWidgets('شریتی بێ ئینتەرنێت', (tester) async {
    final online = StreamController<bool>();
    addTearDown(online.close);
    await tester.pumpWidget(MaterialApp(
      home: OfflineBanner(onlineStream: online.stream, child: const Scaffold(body: Text('page'))),
    ));
    expect(find.byKey(const ValueKey('offline-banner')), findsNothing);
    online.add(false);
    await tester.pump();
    expect(find.byKey(const ValueKey('offline-banner')), findsOneWidget);
    expect(find.text('page'), findsOneWidget);
    online.add(true);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('offline-banner')), findsNothing);
  });
}
