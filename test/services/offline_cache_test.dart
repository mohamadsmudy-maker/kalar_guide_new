import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheService.clear();
  });

  test('fetchList: ئینتەرنێت هەبوو → داتای نوێ و هەڵدەگیرێت', () async {
    final r = await CacheService.fetchList('k1', () async => [{'id': 1}]);
    expect(r, [{'id': 1}]);
    expect(await CacheService.get('k1'), isNotNull);
  });

  test('fetchList: ئینتەرنێت نەما → دوایین لیستی هەڵگیراو (تەنانەت بەسەرچوو)', () async {
    await CacheService.fetchList('k2', () async => [{'id': 7, 'name': 'دادگا'}],
        keepFor: const Duration(milliseconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await CacheService.get('k2'), isNull); // ماوەکەی بەسەرچووە
    final r = await CacheService.fetchList('k2', () async => throw Exception('offline'));
    expect(r.single['name'], 'دادگا');
    expect(r.single, isA<Map<String, dynamic>>());
  });

  test('fetchList: هەرگیز هەڵنەگیرابێت و ئینتەرنێت نەبێت → هەڵە دەدات', () async {
    expect(CacheService.fetchList('k3', () async => throw Exception('offline')), throwsException);
  });

  test('fetchList: لیستی بەتاڵی سێرڤەر کاشی باش ناسڕێتەوە', () async {
    await CacheService.fetchList('k4', () async => [{'id': 1}]);
    final empty = await CacheService.fetchList('k4', () async => []);
    expect(empty, isEmpty);
    expect(await CacheService.getStale('k4'), isNotNull);
  });
}
