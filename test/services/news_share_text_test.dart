import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/l10n/tr.dart';
import 'package:kalar_guide_new/services/news_share_service.dart';

void main() {
  tearDown(() => AppLang.setCode('ku'));

  test('ناونیشان، کورتە، بڵاوکەرەوە و ناوی ئەپ', () {
    final t = NewsShareService.buildText(
      title: 'ئامادەکاری بۆ وەرزی نوێی بارانبارین',
      description: 'ئامادەکارییەکانی وەرزی زستان   و پاراستنی شاری کەلار',
      publisher: 'سەرۆکایەتی شارەوانی کەلار',
    );
    expect(t, startsWith('📰 ئامادەکاری بۆ وەرزی نوێی بارانبارین'));
    expect(t, contains('ئامادەکارییەکانی وەرزی زستان و پاراستنی شاری کەلار'));
    expect(t, contains('🏛️ سەرۆکایەتی شارەوانی کەلار'));
    expect(t, endsWith('📲 ئەپی ڕێبەری کەلار'));
  });

  test('دەقی درێژ لە کۆتایی وشەیەک کورت دەکرێتەوە', () {
    final long = List.filled(100, 'وشە').join(' ');
    final t = NewsShareService.buildText(title: 'x', description: long, maxSummary: 50);
    final summary = t.split('\n\n')[1];
    expect(summary.length, lessThanOrEqualTo(51));
    expect(summary, endsWith('وشە…'));
  });

  test('بێ وەسف و بێ بڵاوکەرەوە', () {
    final t = NewsShareService.buildText(title: 'هەواڵ');
    expect(t.split('\n\n'), hasLength(2));
  });

  test('ناوی ئەپ بە زمانی ئێستا', () {
    AppLang.setCode('en');
    final t = NewsShareService.buildText(title: 'News');
    expect(t, isNot(contains('ڕێبەری')));
  });
}
