import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide/utils/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('hash دەبێت هەمان بەها بۆ هەمان پاسۆرد بگەڕێنێتەوە', () {
      const password = 'test123456';
      final hash1 = PasswordHasher.hash(password);
      final hash2 = PasswordHasher.hash(password);

      expect(hash1, equals(hash2));
    });

    test('hash دەبێت جیاواز بێت بۆ پاسۆردی جیاواز', () {
      final hash1 = PasswordHasher.hash('password1');
      final hash2 = PasswordHasher.hash('password2');

      expect(hash1, isNot(equals(hash2)));
    });

    test('hash دەبێت درێژی 64 بێت (SHA-256)', () {
      final hash = PasswordHasher.hash('test123');
      expect(hash.length, equals(64));
    });

    test('hash ی پاسۆردی بەتاڵ دەبێت بەتاڵ بێت', () {
      final hash = PasswordHasher.hash('');
      expect(hash, isEmpty);
    });

    test('verify دەبێت true بگەڕێنێتەوە بۆ پاسۆردی دروست', () {
      const password = 'test123456';
      final hash = PasswordHasher.hash(password);

      expect(PasswordHasher.verify(password, hash), isTrue);
    });

    test('verify دەبێت false بگەڕێنێتەوە بۆ پاسۆردی هەڵە', () {
      final hash = PasswordHasher.hash('correct');

      expect(PasswordHasher.verify('wrong', hash), isFalse);
    });

    test('verify دەبێت false بگەڕێنێتەوە بۆ hash ی بەتاڵ', () {
      expect(PasswordHasher.verify('test', ''), isFalse);
    });

    test('verify دەبێت false بگەڕێنێتەوە بۆ پاسۆردی بەتاڵ', () {
      final hash = PasswordHasher.hash('test');
      expect(PasswordHasher.verify('', hash), isFalse);
    });

    test('hashLength دەبێت 64 بێت', () {
      expect(PasswordHasher.hashLength, equals(64));
    });
  });
}