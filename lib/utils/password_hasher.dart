// 📁 lib/utils/password_hasher.dart
import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../config/env.dart';

/// 🔐 Hashing ی پاسۆرد — SECURE EDITION + PLAINTEXT MIGRATION
///
/// ✅ bcrypt (logRounds: 12) — پاسۆردی نوێ
/// ⚠️ SHA-256 (legacy) — تەنها بۆ migration
/// ⚠️ Plaintext (legacy) — تەنها بۆ migration (کاتی)
class PasswordHasher {
  PasswordHasher._();

  // ═══════════════════════════════════════════════════════════
  // 🔐 bcrypt — پێشنیارکراو
  // ═══════════════════════════════════════════════════════════

  /// بەرهەمهێنانی Hash ی نوێ بە bcrypt — Sync
  static String hashSync(String password) {
    if (password.isEmpty) return '';
    return BCrypt.hashpw(
      password,
      BCrypt.gensalt(logRounds: 12),
    );
  }

  /// بەرهەمهێنانی Hash لە isolate (بۆ UI)
  static Future<String> hash(String password) async {
    if (password.isEmpty) return '';
    return compute(_hashIsolate, password);
  }

  static String _hashIsolate(String password) {
    return BCrypt.hashpw(
      password,
      BCrypt.gensalt(logRounds: 12),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ پشکنینی پاسۆرد
  // ═══════════════════════════════════════════════════════════

  /// ✅ پشکنینی پاسۆرد — پشتگیری:
  ///   • bcrypt (درێژی 60، `$2a$` / `$2b$` / `$2y$`)
  ///   • SHA-256 (درێژی 64) — legacy
  ///   • Plaintext — legacy (بۆ migration)
  static bool verify(String password, String storedHash) {
    if (password.isEmpty || storedHash.isEmpty) return false;

    // ⚠️ ١. Plaintext legacy (بۆ migration تەنها)
    // ئەمە ڕێگە بە پاسۆردی کۆن دەدات کە هێشتا hash نەکراون
    if (storedHash == password) {
      debugPrint(
        '⚠️ Plaintext password detected — needs upgrade to bcrypt!',
      );
      return true;
    }

    // ✅ ٢. bcrypt: درێژی 60 (دەستپێدەکات بە $2a$/$2b$/$2y$)
    if (storedHash.length == 60 && storedHash.startsWith(r'$2')) {
      try {
        return BCrypt.checkpw(password, storedHash);
      } catch (e) {
        debugPrint('❌ bcrypt verify error: $e');
        return false;
      }
    }

    // ⚠️ ٣. Legacy SHA-256 (درێژی 64)
    if (storedHash.length == 64) {
      try {
        debugPrint(
          '⚠️ SHA-256 hash detected — needs migration to bcrypt',
        );
        final legacyHash = _legacySha256(password);
        return _constantTimeEquals(storedHash, legacyHash);
      } catch (e) {
        debugPrint('❌ SHA-256 verify error: $e');
        return false;
      }
    }

    debugPrint(
      '⚠️ Unknown hash format (length: ${storedHash.length})',
    );
    return false;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Migration check
  // ═══════════════════════════════════════════════════════════

  /// ✅ پشکنین ئەگەر پاسۆردەکە پێویستی بە upgrade هەیە
  ///   • bcrypt = 60 chars، دەستپێدەکات بە `$2` → ✅ نەخێر
  ///   • SHA-256 = 64 chars → ⚠️ بەڵێ
  ///   • Plaintext = هیچ کام → ⚠️ بەڵێ
  static bool needsUpgrade(String storedHash) {
    if (storedHash.isEmpty) return false;

    // اگر bcrypt ە → پێویست بە upgrade نییە
    if (storedHash.length == 60 && storedHash.startsWith(r'$2')) {
      return false;
    }

    // باقی هەموویان (SHA-256، Plaintext، هتد) → پێویست بە upgrade هەیە
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ Legacy SHA-256
  // ═══════════════════════════════════════════════════════════
  static String _legacySha256(String password) {
    final salt = AppEnv.passwordSalt;
    if (salt.isEmpty) {
      throw StateError(
        '❌ PASSWORD_SALT نەدۆزرایەوە — verify legacy hash ناکرێت',
      );
    }
    final salted = '$salt$password$salt';
    final bytes = utf8.encode(salted);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔒 Constant-time comparison
  // ═══════════════════════════════════════════════════════════
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  // ═══════════════════════════════════════════════════════════
  // 📏 Constants
  // ═══════════════════════════════════════════════════════════
  static int get bcryptHashLength => 60;
  static int get legacyHashLength => 64;
}