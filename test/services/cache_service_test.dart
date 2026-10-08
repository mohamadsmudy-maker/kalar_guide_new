import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide/services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CacheService', () {
    test('save و get دەبێت دروست کار بکەن', () async {
      await CacheService.save('test_key', {'name': 'Test'});
      final result = await CacheService.get('test_key');

      expect(result, isNotNull);
      expect(result['name'], equals('Test'));
    });

    test('get بۆ کلیلێکی نەبوو دەبێت null بگەڕێنێتەوە', () async {
      final result = await CacheService.get('non_existent_key');
      expect(result, isNull);
    });

    test('remove دەبێت دروست کار بکات', () async {
      await CacheService.save('test_key', {'data': 'value'});
      await CacheService.remove('test_key');

      final result = await CacheService.get('test_key');
      expect(result, isNull);
    });

    test('has دەبێت دروست کار بکات', () async {
      await CacheService.save('test_key', 'value');
      final hasKey = await CacheService.has('test_key');
      final hasNoKey = await CacheService.has('non_existent');

      expect(hasKey, isTrue);
      expect(hasNoKey, isFalse);
    });

    test('clear دەبێت هەموو کاش بسڕێتەوە', () async {
      await CacheService.save('key1', 'value1');
      await CacheService.save('key2', 'value2');

      await CacheService.clear();

      expect(await CacheService.get('key1'), isNull);
      expect(await CacheService.get('key2'), isNull);
    });

    test('کاشی کۆتایی هاتوو دەبێت null بگەڕێنێتەوە', () async {
      await CacheService.save(
        'expired_key',
        'value',
        duration: const Duration(milliseconds: 100),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      final result = await CacheService.get('expired_key');
      expect(result, isNull);
    });
  });
}