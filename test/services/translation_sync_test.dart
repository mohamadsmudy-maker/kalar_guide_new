import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final calls = <String?>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TranslationService.fetchSharedPage = (lang, since, limit) async {
      calls.add(since);
      if (since != null) return [];
      return [
        {'source': 'بنکەی ئاگرکوژێنەوە', 'translation': 'Fire station', 'updated_at': '2026-11-08T10:00:00Z'},
        {'source': ' کەلار ', 'translation': 'Kalar', 'updated_at': '2026-11-08T11:00:00Z'},
      ];
    };
  });

  tearDown(() {
    TranslationService.fetchSharedPage = null;
    TranslationService.fetchOverride = null;
  });

  // پێشتر whenComplete چاوەڕێی خۆی دەکرد و ئەم Future ـە هەرگیز تەواو نەدەبوو
  test('translate() completes for text that is not cached yet', () async {
    var calls = 0;
    TranslationService.fetchOverride = (text, lang) async {
      calls++;
      return 'Hospital';
    };
    final a = TranslationService.translate(text: 'نەخۆشخانە', targetLanguage: 'en');
    final b = TranslationService.translate(text: 'نەخۆشخانە', targetLanguage: 'en');
    expect(await a.timeout(const Duration(seconds: 2)), 'Hospital');
    expect(await b.timeout(const Duration(seconds: 2)), 'Hospital');
    expect(calls, 1, reason: 'same text in flight → one request');
  });

  test('shared translations are downloaded once, then only newer rows', () async {
    expect(await TranslationService.syncShared('en'), 2);
    expect(TranslationService.cachedOrNull('بنکەی ئاگرکوژێنەوە', 'en'), 'Fire station');
    expect(TranslationService.cachedOrNull('کەلار', 'en'), 'Kalar');
    expect(await TranslationService.translate(text: 'کەلار', targetLanguage: 'en'), 'Kalar');

    // دووەم جار: تەنها ڕیزە نوێکان (دوای دوایین updated_at)
    expect(await TranslationService.syncShared('en'), 0);
    expect(calls.last, '2026-11-08T11:00:00Z');
  });

  test('Kurdish never syncs and failures are harmless', () async {
    final before = calls.length;
    expect(await TranslationService.syncShared('ku'), 0);
    expect(calls.length, before);

    TranslationService.fetchSharedPage = (_, __, ___) async => throw Exception('offline');
    expect(await TranslationService.syncShared('ar'), 0);
  });
}
