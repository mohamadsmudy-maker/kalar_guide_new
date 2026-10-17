// 📁 test/services/password_hasher_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/utils/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    // ═══════════════════════════════════════════════════════════
    // 🔐 hashSync — سینکرۆنی
    // ═══════════════════════════════════════════════════════════
    test('hashSync returns 60 char string (bcrypt)', () {
      final hash = PasswordHasher.hashSync('password123');
      expect(hash.length, 60);
      expect(hash.startsWith(r'$2'), true);
    });

    test('hashSync returns empty for empty password', () {
      final hash = PasswordHasher.hashSync('');
      expect(hash, '');
    });

    // ═══════════════════════════════════════════════════════════
    // 🔐 hash — ئاسۆکرۆنی
    // ═══════════════════════════════════════════════════════════
    test('hash returns 60 char string (bcrypt)', () async {
      final hash = await PasswordHasher.hash('password123');
      expect(hash.length, 60);
      expect(hash.startsWith(r'$2'), true);
    });

    test('hash returns empty for empty password', () async {
      final hash = await PasswordHasher.hash('');
      expect(hash, '');
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
    // 🔄 needsUpgrade
    // ═══════════════════════════════════════════════════════════
    test('needsUpgrade returns false for bcrypt hash', () async {
      final hash = await PasswordHasher.hash('password123');
      expect(PasswordHasher.needsUpgrade(hash), false);
    });

    test('needsUpgrade returns true for SHA-256 hash (64 chars)', () {
      final sha256Hash = 'a' * 64; // ٦٤ پیت
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