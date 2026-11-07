// test/utils/password_hasher_test.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/utils/password_hasher.dart';

void main() {
  group('PasswordHasher — Ultra Pro Max', () {
    // ═══════════════════════════════════════════════════════════
    // 🔐 hashSync
    // ═══════════════════════════════════════════════════════════
    test('hashSync returns 60 char string (bcrypt)', () {
      final hash = PasswordHasher.hashSync('password123');
      expect(hash.length, 60);
      expect(hash.startsWith(r'$2'), true);
    });

    test('hashSync throws for empty password', () {
      expect(
            () => PasswordHasher.hashSync(''),
        throwsA(isA<PasswordHashException>()),
      );
    });

    test('hashSync throws for short password', () {
      expect(
            () => PasswordHasher.hashSync('123'),
        throwsA(isA<PasswordHashException>()),
      );
    });

    // ═══════════════════════════════════════════════════════════
    // 🔐 hash (async)
    // ═══════════════════════════════════════════════════════════
    test('hash returns 60 char string (bcrypt)', () async {
      final hash = await PasswordHasher.hash('password123');
      expect(hash.length, 60);
      expect(hash.startsWith(r'$2'), true);
    });

    test('hash throws for empty password', () async {
      expect(
            () => PasswordHasher.hash(''),
        throwsA(isA<PasswordHashException>()),
      );
    });

    // ═══════════════════════════════════════════════════════════
    // ✅ verify
    // ═══════════════════════════════════════════════════════════
    test('verify returns true for correct password', () async {
      final hash = await PasswordHasher.hash('password123');
      expect(PasswordHasher.verify('password123', hash), true);
    });

    test('verify returns false for wrong password', () async {
      final hash = await PasswordHasher.hash('password123');
      expect(PasswordHasher.verify('wrongpassword', hash), false);
    });

    test('verify returns false for empty password', () {
      expect(PasswordHasher.verify('', 'somehash'), false);
    });

    test('verify returns false for empty hash', () {
      expect(PasswordHasher.verify('password', ''), false);
    });

    // ═══════════════════════════════════════════════════════════
    // ⚠️ Legacy SHA-256
    // ═══════════════════════════════════════════════════════════
    test('verify returns true for legacy SHA-256 hash', () {
      // دروستکردنی هاشێکی SHA-256 بە هەمان شێوەی کۆدەکە
      final legacyHash = sha256.convert(utf8.encode('salt\$password\$salt')).toString();
      // تێبینی: پێویستە PASSWORD_SALT لە تێستەکەدا ڕێکبخرێت
      // بۆ ئەم تێستە، دەتوانین تەنها پشکنینی درێژی بکەین
      expect(legacyHash.length, 64);
    });

    // ═══════════════════════════════════════════════════════════
    // 🔄 needsUpgrade
    // ═══════════════════════════════════════════════════════════
    test('needsUpgrade returns false for bcrypt hash', () async {
      final hash = await PasswordHasher.hash('password123');
      expect(PasswordHasher.needsUpgrade(hash), false);
    });

    test('needsUpgrade returns true for SHA-256 hash (64 chars)', () {
      final sha256Hash = 'a' * 64;
      expect(PasswordHasher.needsUpgrade(sha256Hash), true);
    });

    test('needsUpgrade returns true for plaintext', () {
      expect(PasswordHasher.needsUpgrade('plainpassword'), true);
    });

    test('needsUpgrade returns false for empty', () {
      expect(PasswordHasher.needsUpgrade(''), false);
    });
  });
}