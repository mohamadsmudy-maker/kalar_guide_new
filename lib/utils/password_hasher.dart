import 'dart:convert';
import 'package:crypto/crypto.dart';

/// 🔐 Hashing ی پاسۆرد بە SHA-256
/// ⚠️ تێبینی: بۆ ئاسایشی بەرزتر، Supabase Auth بەکاربهێنە
class PasswordHasher {
  /// ✅ Salt ی جێگیر
  /// ⚠️ بۆ Production، دەبێت لە .env یان --dart-define بێت
  static String get _salt {
    const fromEnv = String.fromEnvironment(
      'PASSWORD_SALT',
      defaultValue: '',
    );
    if (fromEnv.isNotEmpty) return fromEnv;

    // ⚠️ Fallback — دەبێت لەگەڵ SQL Script بگونجێت
    return 'kalar_guide_2024_secure_salt_v1_change_me';
  }

  /// 🔐 Hashing ی پاسۆرد
  static String hash(String password) {
    if (password.isEmpty) return '';

    final salted = '$_salt$password$_salt';
    final bytes = utf8.encode(salted);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  /// ✅ پشکنینی پاسۆرد
  static bool verify(String password, String storedHash) {
    if (password.isEmpty || storedHash.isEmpty) return false;
    return hash(password) == storedHash;
  }

  /// ✅ درێژی Hashing
  static int get hashLength => 64; // SHA-256 = 64 hex chars
}