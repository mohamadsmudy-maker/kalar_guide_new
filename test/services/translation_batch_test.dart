import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final calls = <int>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TranslationService.fetchBatchOverride = (texts, lang) async {
      calls.add(texts.length);
      // «شکست» بۆ هەر دەقێک کە بە x کۆتایی دێت (وەک 429)
      return [for (final t in texts) t.endsWith('x') ? null : 'EN:$t'];
    };
  });

  tearDown(() => TranslationService.fetchBatchOverride = null);

  test('many names on screen become a few batch requests', () async {
    final futures = [
      for (var i = 0; i < 100; i++)
        TranslationService.tryTranslate(text: 'شوێنی $i', targetLanguage: 'en'),
    ];
    final res = await Future.wait(futures).timeout(const Duration(seconds: 5));
    expect(calls, [40, 40, 20], reason: '100 texts → 3 requests');
    expect(res.first, 'EN:شوێنی 0');
    expect(TranslationService.cachedOrNull('شوێنی 99', 'en'), 'EN:شوێنی 99');
  });

  test('a failed text is not cached as its own Kurdish text', () async {
    final r = await TranslationService.tryTranslate(text: 'نەناسراوx', targetLanguage: 'en')
        .timeout(const Duration(seconds: 5));
    expect(r, isNull);
    expect(TranslationService.cachedOrNull('نەناسراوx', 'en'), isNull);
    // translate() هێشتا دەقی ڕەسەن پیشان دەدات
    expect(
      await TranslationService.translate(text: 'نەناسراوx', targetLanguage: 'en'),
      'نەناسراوx',
    );
  });

  test('admin "translate all" skips cached texts and reports progress', () async {
    final progress = <int>[];
    final n = await TranslationService.translateAllNow(
      ['ناوی ١', 'ناوی ٢', 'ناوی ٣x', '0770 123'],
      'ar',
      pause: Duration.zero,
      onProgress: (done, total) => progress.add(done),
    );
    expect(n, 2);
    expect(calls, [3], reason: 'phone number is not sent');
    expect(progress, [3]);
    final again = await TranslationService.translateAllNow(['ناوی ١'], 'ar', pause: Duration.zero);
    expect(again, 0);
    expect(calls, [3], reason: 'already cached → no request');
  });
}
