import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🚦 Rate Limiter — پاراستن لە هەوڵی زۆر
class RateLimiter {
  static const int maxAttempts = 5;
  static const int blockDurationMinutes = 15;
  static const int windowMinutes = 15;

  // ═══════════════════════════════════════════════════════════
  // 📊 پشکنین
  // ═══════════════════════════════════════════════════════════
  static Future<bool> isBlocked(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockUntil = prefs.getInt('block_until_$key') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (blockUntil > now) {
        final remaining = blockUntil - now;
        final minutes = (remaining / 60000).ceil();
        debugPrint('🚫 بلۆککراوە بۆ $minutes خولەکی تر');
        return true;
      }

      if (blockUntil > 0 && blockUntil <= now) {
        await prefs.remove('block_until_$key');
        await prefs.remove('attempts_$key');
        await prefs.remove('first_attempt_$key');
      }

      return false;
    } catch (e) {
      debugPrint('❌ isBlocked error: $e');
      return false;
    }
  }

  static Future<int> getRemainingBlockMinutes(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockUntil = prefs.getInt('block_until_$key') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (blockUntil > now) {
        final remaining = blockUntil - now;
        return (remaining / 60000).ceil();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 تۆمارکردن
  // ═══════════════════════════════════════════════════════════
  static Future<void> recordFailedAttempt(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      const windowMs = windowMinutes * 60 * 1000;

      final firstAttempt = prefs.getInt('first_attempt_$key') ?? 0;
      int attempts = prefs.getInt('attempts_$key') ?? 0;

      if (firstAttempt == 0 || (now - firstAttempt) > windowMs) {
        attempts = 0;
        await prefs.setInt('first_attempt_$key', now);
      }

      attempts++;
      await prefs.setInt('attempts_$key', attempts);

      debugPrint('⚠️ هەوڵی شکست: $attempts/$maxAttempts');

      if (attempts >= maxAttempts) {
        final blockUntil = now + (blockDurationMinutes * 60 * 1000);
        await prefs.setInt('block_until_$key', blockUntil);
        debugPrint('🚫 بلۆککرا بۆ $blockDurationMinutes خولەک');
      }
    } catch (e) {
      debugPrint('❌ recordFailedAttempt error: $e');
    }
  }

  static Future<void> reset(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('attempts_$key');
      await prefs.remove('first_attempt_$key');
      await prefs.remove('block_until_$key');
      debugPrint('✅ Rate limit reset: $key');
    } catch (e) {
      debugPrint('❌ reset error: $e');
    }
  }

  static Future<int> getAttempts(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('attempts_$key') ?? 0;
    } catch (e) {
      return 0;
    }
  }
}