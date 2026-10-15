import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/news.dart';

void main() {
  group('News Model — تێستی زیاتر', () {
    test('copyWith دەبێت دروست کار بکات', () {
      final original = News(
        id: '1',
        title: 'Original',
        description: 'Desc',
        likes: 10,
        views: 100,
      );

      final updated = original.copyWith(
        title: 'Updated',
        likes: 20,
      );

      expect(updated.id, equals('1'));
      expect(updated.title, equals('Updated'));
      expect(updated.likes, equals(20));
      expect(updated.views, equals(100));
    });

    test('toJson دەبێت دروست کار بکات', () {
      final news = News(
        id: '1',
        title: 'Test',
        description: 'Desc',
        images: ['img1.jpg'],
        likes: 10,
        views: 100,
      );

      final json = news.toJson();

      expect(json['id'], equals('1'));
      expect(json['title'], equals('Test'));
      expect(json['images'], equals(['img1.jpg']));
      expect(json['likes'], equals(10));
      expect(json['views'], equals(100));
    });

    test('images بە String جیاکراوە', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'description': 'Desc',
        'images': 'img1.jpg, img2.jpg, img3.jpg',
      };

      final news = News.fromJson(json);

      expect(news.images.length, equals(3));
      expect(news.images.first, equals('img1.jpg'));
    });

    test('بەتاڵ images', () {
      final news = News(
        title: 'Test',
        description: 'Desc',
      );

      expect(news.images, isEmpty);
      expect(news.primaryImage, isNull);
      expect(news.hasImage, isFalse);
    });
  });
}