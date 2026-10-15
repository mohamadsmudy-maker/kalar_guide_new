import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/emergency_service.dart';

void main() {
  group('EmergencyService Model', () {
    test('fromJson دەبێت دروست کار بکات', () {
      final json = {
        'id': 1,
        'name_ku': 'پۆلیسی کەلار',
        'name_ar': 'شرطة كلار',
        'name_en': 'Kalar Police',
        'category': 'police',
        'phone': '104',
        'phone_alt': '0770',
        'address': 'کەلار',
        'icon': 'local_police',
        'color': '#1E88E5',
        'is_important': true,
        'is_24h': true,
        'display_order': 1,
        'notes': 'تێبینی',
        'authority_name': 'بەڕێوەبەرایەتی پۆلیس',
      };

      final service = EmergencyService.fromJson(json);

      expect(service.id, equals('1'));
      expect(service.nameKu, equals('پۆلیسی کەلار'));
      expect(service.nameAr, equals('شرطة كلار'));
      expect(service.nameEn, equals('Kalar Police'));
      expect(service.category, equals('police'));
      expect(service.phone, equals('104'));
      expect(service.phoneAlt, equals('0770'));
      expect(service.address, equals('کەلار'));
      expect(service.isImportant, isTrue);
      expect(service.is24h, isTrue);
      expect(service.displayOrder, equals(1));
      expect(service.notes, equals('تێبینی'));
      expect(service.authorityName, equals('بەڕێوەبەرایەتی پۆلیس'));
    });

    test('fromJson بە داتای بەتاڵ دەبێت کار بکات', () {
      final json = <String, dynamic>{};
      final service = EmergencyService.fromJson(json);

      expect(service.id, isNull);
      expect(service.nameKu, equals(''));
      expect(service.category, equals('other'));
      expect(service.phone, equals(''));
      expect(service.isImportant, isFalse);
      expect(service.is24h, isTrue);
    });

    test('getName دەبێت ناوی دروست بگەڕێنێتەوە', () {
      final service = EmergencyService(
        nameKu: 'پۆلیس',
        nameAr: 'شرطة',
        nameEn: 'Police',
        category: 'police',
        phone: '104',
      );

      expect(service.getName('ku'), equals('پۆلیس'));
      expect(service.getName('ar'), equals('شرطة'));
      expect(service.getName('en'), equals('Police'));
    });

    test('getName دەبێت بگەڕێتەوە بۆ nameKu ئەگەر nameAr بەتاڵ بوو', () {
      final service = EmergencyService(
        nameKu: 'پۆلیس',
        nameAr: null,
        nameEn: null,
        category: 'police',
        phone: '104',
      );

      expect(service.getName('ar'), equals('پۆلیس'));
      expect(service.getName('en'), equals('پۆلیس'));
    });

    test('hasLocation دەبێت false بگەڕێنێتەوە بێ لۆکەیشن', () {
      final service = EmergencyService(
        nameKu: 'test',
        category: 'police',
        phone: '104',
      );

      expect(service.hasLocation, isFalse);
    });

    test('hasLocation دەبێت true بگەڕێنێتەوە لەگەڵ لۆکەیشن', () {
      final service = EmergencyService(
        nameKu: 'test',
        category: 'police',
        phone: '104',
        latitude: 34.6189,
        longitude: 45.3156,
      );

      expect(service.hasLocation, isTrue);
    });

    test('hasLocation دەبێت false بگەڕێنێتەوە ئەگەر lat/lng = 0', () {
      final service = EmergencyService(
        nameKu: 'test',
        category: 'police',
        phone: '104',
        latitude: 0,
        longitude: 0,
      );

      expect(service.hasLocation, isFalse);
    });
  });
}