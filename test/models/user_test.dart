import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/user.dart';

void main() {
  group('AppUser Model', () {
    test('fromJson دەبێت دروست کار بکات', () {
      final json = {
        'id': '123',
        'name': 'محمد',
        'phone': '07701234567',
        'role': 'admin',
        'is_approved': true,
      };

      final user = AppUser.fromJson(json);

      expect(user.id, equals('123'));
      expect(user.name, equals('محمد'));
      expect(user.role, equals('admin'));
      expect(user.isApproved, isTrue);
    });

    test('isAdmin دەبێت true بگەڕێنێتەوە', () {
      final user = AppUser(role: 'admin');
      expect(user.isAdmin, isTrue);
      expect(user.isVendor, isTrue);
      expect(user.isCustomer, isFalse);
    });

    test('isVendor دەبێت true بگەڕێنێتەوە', () {
      final user = AppUser(role: 'vendor');
      expect(user.isVendor, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.isCustomer, isFalse);
    });

    test('isCustomer دەبێت true بگەڕێنێتەوە', () {
      final user = AppUser(role: 'customer');
      expect(user.isCustomer, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.isVendor, isFalse);
    });

    test('copyWith دەبێت دروست کار بکات', () {
      final user = AppUser(
        id: '1',
        name: 'Ali',
        phone: '0770',
        role: 'customer',
      );

      final updated = user.copyWith(name: 'Ahmad', role: 'vendor');

      expect(updated.id, equals('1'));
      expect(updated.name, equals('Ahmad'));
      expect(updated.role, equals('vendor'));
      expect(updated.phone, equals('0770'));
    });

    test('toJson دەبێت دروست کار بکات', () {
      final user = AppUser(
        id: '1',
        name: 'Ali',
        phone: '0770',
        role: 'customer',
      );

      final json = user.toJson();

      expect(json['id'], equals('1'));
      expect(json['name'], equals('Ali'));
      expect(json['phone'], equals('0770'));
      expect(json['role'], equals('customer'));
    });
  });
}