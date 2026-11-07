// lib/utils/password_hasher.dart
import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// 🔐 Hashing ی پاسۆرد
///
/// ⚠️ ئەم کلاسە تەنها بۆ گواستنەوەی (migration) بەکارهێنەرە کۆنەکانە.
/// پشکنینی پاسۆرد دەبێت لە کۆتاییدا بچێتە سەر سێرڤەر (Edge Function)
/// بۆ ئەوەی ئەپەکە هەرگیز hash ی پاسۆرد نەبینێت.
class PasswordHasher {
  PasswordHasher._();

  static const int _minPasswordLength = 8;
  static const int _bcryptRounds = 12;

  static const int bcryptHashLength = 60;
  static const int legacyHashLength = 64;

  static final RegExp _bcryptPattern =
  RegExp(r'^\$2[abxy]?\$\d{2}\$[./A-Za-z0-9]{53}$');
  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

  // ═══════════════════════════════════════════════════════════
  // 🔐 دروستکردنی hash (bcrypt)
  // ═══════════════════════════════════════════════════════════

  /// UI دەوەستێنێت (~٢٠٠-٥٠٠ms) — باشترە [hash] بەکاربهێنیت.
  static String hashSync(String password) {
    _validatePassword(password);
    return _hashIsolate(password);
  }

  static Future<String> hash(String password) async {
    _validatePassword(password);
    return compute(_hashIsolate, password);
  }

  static String _hashIsolate(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: _bcryptRounds));
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ پشکنینی پاسۆرد
  // ═══════════════════════════════════════════════════════════

  /// پشکنین لە isolate ی جیاوازدا — UI ناوەستێنێت.
  static Future<bool> verifyAsync(String password, String storedHash) {
    return compute(_verifyIsolate, (password, storedHash));
  }

  static bool _verifyIsolate((String, String) args) =>
      verify(args.$1, args.$2);

  static bool verify(String password, String storedHash) {
    if (password.isEmpty || storedHash.isEmpty) return false;

    // ١. bcrypt
    if (isBcrypt(storedHash)) {
      try {
        return BCrypt.checkpw(password, storedHash);
      } catch (e) {
        debugPrint('❌ bcrypt verify error: $e');
        return false;
      }
    }

    // ٢. Legacy SHA-256 (+ salt)
    if (_sha256Pattern.hasMatch(storedHash)) {
      try {
        debugPrint('⚠️ SHA-256 hash detected — needs migration to bcrypt');
        final legacyHash = _legacySha256(password);
        return _constantTimeEquals(storedHash.toLowerCase(), legacyHash);
      } catch (e) {
        debugPrint('❌ SHA-256 verify error: $e');
        return false;
      }
    }

    // ٣. Plaintext legacy — تەنها کاتێک نرخەکە شێوەی hash ی نییە.
    // 🔒 چاککراوە: پێشتر ئەگەر کەسێک hash ەکەی وەک پاسۆرد بنووسیبا،
    //    `storedHash == password` ڕاست دەبوو و دەچووە ژوورەوە.
    //    ئێستا hash ەکان سەرەوە پشکنین دەکرێن و هەرگیز ناگەنە ئێرە.
    debugPrint('⚠️ Plaintext password detected — needs upgrade to bcrypt!');
    return _constantTimeEquals(storedHash, password);
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Migration check
  // ═══════════════════════════════════════════════════════════

  /// `true` ئەگەر hash ەکە bcrypt نەبێت — دوای login ی سەرکەوتوو
  /// پاسۆردەکە بە [hash] دووبارە hash بکە و لە داتابەیس نوێی بکەرەوە.
  static bool needsUpgrade(String storedHash) {
    if (storedHash.isEmpty) return false;
    return !isBcrypt(storedHash);
  }

  static bool isBcrypt(String value) => _bcryptPattern.hasMatch(value);

  // ═══════════════════════════════════════════════════════════
  // 🛠️ Helpers
  // ═══════════════════════════════════════════════════════════
  static void _validatePassword(String password) {
    if (password.isEmpty) {
      throw const PasswordHashException('پاسۆرد ناتوانێت بەتاڵ بێت');
    }
    if (password.length < _minPasswordLength) {
      throw const PasswordHashException(
        'پاسۆرد دەبێت لانیکەم $_minPasswordLength کاراکتەر بێت',
      );
    }
  }

  /// salt ی کۆن — تەنها ئەگەر بە `--dart-define=PASSWORD_SALT=...` درابێت.
  /// ئەگەر نەدرابێت، بەکارهێنەرە SHA-256 ـە کۆنەکان ناتوانن بچنە ژوورەوە.
  static const String _legacySalt = String.fromEnvironment('PASSWORD_SALT');

  static String _legacySha256(String password) {
    const salt = _legacySalt;
    if (salt.isEmpty) {
      throw const PasswordHashException(
        'PASSWORD_SALT نەدۆزرایەوە — verify legacy hash ناکرێت',
      );
    }
    final salted = '$salt$password$salt';
    return sha256.convert(utf8.encode(salted)).toString();
  }

  static bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) return false;
    var result = 0;
    for (var i = 0; i < aBytes.length; i++) {
      result |= aBytes[i] ^ bBytes[i];
    }
    return result == 0;
  }
}

/// ❌ هەڵەی تایبەت بۆ هاشکردنی پاسۆرد
class PasswordHashException implements Exception {
  final String message;
  const PasswordHashException(this.message);

  @override
  String toString() => 'PasswordHashException: $message';
}
