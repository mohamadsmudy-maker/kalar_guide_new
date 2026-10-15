import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/news.dart';


void main() {
  group('News Model', () {
    test('fromJson دەبێت دروست کار بکات', () {
      final json = {
        'id': 1,
        'store_id': 'store1',
        'title': 'ناونیشان',
        'description': 'وەسف',
        'images': ['img1.jpg', 'img2.jpg'],
        'likes': 10,
        'views': 100,
        'created_at': '2024-01-01T10:00:00Z',
      };

      final news = News.fromJson(json);

      expect(news.id, equals('1'));
      expect(news.title, equals('ناونیشان'));
      expect(news.images.length, equals(2));
      expect(news.likes, equals(10));
      expect(news.views, equals(100));
    });

    test('id دەبێت String بێت', () {
      final json = {
        'id': 123,
        'title': 'Test',
        'description': 'Test',
      };

      final news = News.fromJson(json);
      expect(news.id, isA<String?>());
    });

    test('primaryImage دەبێت یەکەم وێنە بگەڕێنێتەوە', () {
      final news = News(
        title: 'Test',
        description: 'Test',
        images: ['img1.jpg', 'img2.jpg'],
      );

      expect(news.primaryImage, equals('img1.jpg'));
    });

    test('hasImage دەبێت دروست کار بکات', () {
      final withImage = News(
        title: 'Test',
        description: 'Test',
        images: ['img1.jpg'],
      );

      final withoutImage = News(
        title: 'Test',
        description: 'Test',
      );

      expect(withImage.hasImage, isTrue);
      expect(withoutImage.hasImage, isFalse);
    });

    test('getTimeAgo دەبێت "پێش ئێستا" بگەڕێنێتەوە بۆ نوێ', () {
      final news = News(
        title: 'Test',
        description: 'Test',
        createdAt: DateTime.now(),
      );

      expect(news.getTimeAgo(), contains('چرکەیەک'));
    });

    test('getTimeAgo دەبێت "دەقیقە" بگەڕێنێتەوە', () {
      final news = News(
        title: 'Test',
        description: 'Test',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(news.getTimeAgo(), contains('5 دەقیقە'));
    });

    test('getTimeAgo بۆ کاتی null', () {
      final news = News(title: 'Test', description: 'Test');
      expect(news.getTimeAgo(), equals('کەمێک پێش ئێستا'));
    });
  });
}