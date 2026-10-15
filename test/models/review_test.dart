import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/review.dart';

void main() {
  group('Review Model', () {
    test('fromJson بە rating ی هەڵە', () {
      final json = {
        'id': '1',
        'store_id': 5,
        'user_name': 'Test',
        'rating': 10, // ✅ دەبێت وەک 10 پاشەکەوت بکرێت (validation لە Repository)
      };

      final review = Review.fromJson(json);
      expect(review.rating, equals(10));
    });

    test('getTimeAgo بۆ چەند حاڵەت', () {
      final now = DateTime.now();

      final justNow = Review(
        storeId: 1,
        userName: 'T',
        rating: 5,
        createdAt: now.subtract(const Duration(seconds: 30)),
      );
      expect(justNow.getTimeAgo(), equals('ئێستا'));

      final minutesAgo = Review(
        storeId: 1,
        userName: 'T',
        rating: 5,
        createdAt: now.subtract(const Duration(minutes: 30)),
      );
      expect(minutesAgo.getTimeAgo(), contains('30 خولەک'));

      final hoursAgo = Review(
        storeId: 1,
        userName: 'T',
        rating: 5,
        createdAt: now.subtract(const Duration(hours: 5)),
      );
      expect(hoursAgo.getTimeAgo(), contains('5 کاتژمێر'));

      final daysAgo = Review(
        storeId: 1,
        userName: 'T',
        rating: 5,
        createdAt: now.subtract(const Duration(days: 3)),
      );
      expect(daysAgo.getTimeAgo(), contains('3 ڕۆژ'));
    });
  });

  group('StoreRating — percentFor', () {
    test('کاتێک totalReviews = 0', () {
      final rating = StoreRating(
        storeId: 1,
        totalReviews: 0,
        averageRating: 0,
        count5: 0,
        count4: 0,
        count3: 0,
        count2: 0,
        count1: 0,
      );

      expect(rating.percentFor(5), equals(0));
      expect(rating.percentFor(1), equals(0));
    });

    test('کاتێک هەموو 5 ئەستێرە', () {
      final rating = StoreRating(
        storeId: 1,
        totalReviews: 100,
        averageRating: 5.0,
        count5: 100,
        count4: 0,
        count3: 0,
        count2: 0,
        count1: 0,
      );

      expect(rating.percentFor(5), equals(100.0));
      expect(rating.percentFor(4), equals(0.0));
    });
  });
}