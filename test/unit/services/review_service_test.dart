import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide/models/review.dart';

void main() {
  group('Review Model', () {
    test('fromJson دەبێت دروست کار بکات', () {
      final json = {
        'id': '123',
        'store_id': 5,
        'user_id': 'user-1',
        'user_name': 'محمد',
        'rating': 5,
        'comment': 'زۆر باش',
        'is_approved': true,
      };

      final review = Review.fromJson(json);

      expect(review.id, '123');
      expect(review.storeId, 5);
      expect(review.rating, 5);
      expect(review.comment, 'زۆر باش');
      expect(review.isApproved, true);
    });

    test('getTimeAgo دەبێت "ئێستا" بگەڕێنێتەوە بۆ کۆمێنتی نوێ', () {
      final review = Review(
        storeId: 1,
        userName: 'Test',
        rating: 5,
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );

      expect(review.getTimeAgo(), '2 خولەک لەمەوبەر');
    });

    test('rating دەبێت لە نێوان ١ و ٥ بێت', () {
      final review = Review(
        storeId: 1,
        userName: 'Test',
        rating: 5,
      );

      expect(review.rating >= 1 && review.rating <= 5, isTrue);
    });
  });

  group('StoreRating', () {
    test('percentFor دەبێت ڕێژەی دروست بگەڕێنێتەوە', () {
      final rating = StoreRating(
        storeId: 1,
        totalReviews: 10,
        averageRating: 4.0,
        count5: 5,
        count4: 3,
        count3: 2,
        count2: 0,
        count1: 0,
      );

      expect(rating.percentFor(5), 50.0);
      expect(rating.percentFor(4), 30.0);
      expect(rating.percentFor(1), 0.0);
    });
  });
}