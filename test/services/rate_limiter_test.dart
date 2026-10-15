import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/rate_limiter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RateLimiter', () {
    test('دەبێت بلۆک نەبێت لە سەرەتا', () async {
      final isBlocked = await RateLimiter.isBlocked('test');
      expect(isBlocked, isFalse);
    });

    test('دوای ٥ هەوڵ دەبێت بلۆک بێت', () async {
      for (int i = 0; i < 5; i++) {
        await RateLimiter.recordFailedAttempt('test');
      }
      final isBlocked = await RateLimiter.isBlocked('test');
      expect(isBlocked, isTrue);
    });

    test('دوای ٤ هەوڵ هێشتا بلۆک نەبێت', () async {
      for (int i = 0; i < 4; i++) {
        await RateLimiter.recordFailedAttempt('test');
      }
      final isBlocked = await RateLimiter.isBlocked('test');
      expect(isBlocked, isFalse);
    });

    test('reset دەبێت هەوڵەکان بسڕێتەوە', () async {
      for (int i = 0; i < 3; i++) {
        await RateLimiter.recordFailedAttempt('test');
      }
      await RateLimiter.reset('test');
      final attempts = await RateLimiter.getAttempts('test');
      expect(attempts, equals(0));
    });

    test('reset دەبێت بلۆکیش بسڕێتەوە', () async {
      for (int i = 0; i < 5; i++) {
        await RateLimiter.recordFailedAttempt('test');
      }
      await RateLimiter.reset('test');
      final isBlocked = await RateLimiter.isBlocked('test');
      expect(isBlocked, isFalse);
    });

    test('getRemainingBlockMinutes دەبێت 0 بگەڕێنێتەوە بێ بلۆک', () async {
      final minutes = await RateLimiter.getRemainingBlockMinutes('test');
      expect(minutes, equals(0));
    });

    test('getRemainingBlockMinutes دەبێت > 0 بگەڕێنێتەوە دوای بلۆک', () async {
      for (int i = 0; i < 5; i++) {
        await RateLimiter.recordFailedAttempt('test');
      }
      final minutes = await RateLimiter.getRemainingBlockMinutes('test');
      expect(minutes, greaterThan(0));
    });

    test('keys ی جیاواز دەبێت جیاواز بن', () async {
      await RateLimiter.recordFailedAttempt('user1');
      await RateLimiter.recordFailedAttempt('user2');

      final attempts1 = await RateLimiter.getAttempts('user1');
      final attempts2 = await RateLimiter.getAttempts('user2');

      expect(attempts1, equals(1));
      expect(attempts2, equals(1));
    });

    test('getAttempts دەبێت دروست بگەڕێنێتەوە', () async {
      await RateLimiter.recordFailedAttempt('test');
      await RateLimiter.recordFailedAttempt('test');

      final attempts = await RateLimiter.getAttempts('test');
      expect(attempts, equals(2));
    });
  });
}