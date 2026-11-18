import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/share_intent_service.dart';

void main() {
  test('پۆستی Facebook: یەکەم دێڕ ناونیشانە، لینک دەبێتە سەرچاوە', () {
    final d = SharedNewsDraft.fromShare(
      text: 'ئامادەکاری بۆ وەرزی بارانبارین\nشارەوانیی کەلار دەستی کرد بە پاککردنەوەی جۆگەلەکان.\n'
          'https://www.facebook.com/share/p/abc123/',
    );
    expect(d.title, 'ئامادەکاری بۆ وەرزی بارانبارین');
    expect(d.description, startsWith('شارەوانیی کەلار دەستی کرد'));
    expect(d.description, contains('🔗 سەرچاوە: Facebook'));
    expect(d.description, endsWith('https://www.facebook.com/share/p/abc123/'));
    expect(d.sourceUrl, 'https://www.facebook.com/share/p/abc123/');
  });

  test('تەنها لینک (Facebook زۆر جار تەنها لینک دەنێرێت)', () {
    final d = SharedNewsDraft.fromShare(text: 'https://fb.watch/xyz/');
    expect(d.title, isEmpty);
    expect(d.description, '🔗 سەرچاوە: Facebook\nhttps://fb.watch/xyz/');
  });

  test('subject دەبێتە ناونیشان؛ ناونیشانی درێژ کورت دەکرێتەوە', () {
    expect(SharedNewsDraft.fromShare(text: 'دەق', subject: 'ناونیشان').title, 'ناونیشان');
    final long = List.filled(40, 'وشە').join(' ');
    final d = SharedNewsDraft.fromShare(text: long);
    expect(d.title.length, lessThanOrEqualTo(121));
    expect(d.title, endsWith('…'));
    expect(d.description, long, reason: 'full text kept in the description');
  });

  test('ناوی سەرچاوە', () {
    expect(SharedNewsDraft.sourceName('https://m.facebook.com/x'), 'Facebook');
    expect(SharedNewsDraft.sourceName('https://t.me/kalar'), 'Telegram');
    expect(SharedNewsDraft.sourceName('https://www.kalar.gov.krd/news/1'), 'kalar.gov.krd');
  });

  test('تەنها وێنە', () {
    final d = SharedNewsDraft.fromShare(images: const ['/tmp/a.jpg']);
    expect(d.isEmpty, isFalse);
    expect(d.imagePaths, ['/tmp/a.jpg']);
    expect(SharedNewsDraft.fromShare(text: '  ').isEmpty, isTrue);
  });
}
