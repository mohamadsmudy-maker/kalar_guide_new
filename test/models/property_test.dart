import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/property.dart';  // ✅ چاککرا

void main() {
  group('Property Model', () {
    test('fromJson دەبێت دروست کار بکات', () {
      final json = {
        'id': 1,
        'property_type': 'house',
        'listing_type': 'sale',
        'title_ku': 'خانووی تاقیکردنەوە',
        'title_ar': 'منزل تجريبي',
        'title_en': 'Test House',
        'description_ku': 'وەسف',
        'price': 100000000,
        'area_sqm': 200,
        'rooms': 3,
        'bathrooms': 2,
        'address': 'کەلار',
        'owner_name': 'ئەحمەد',
        'owner_phone': '07701234567',
        'latitude': 34.6189,
        'longitude': 45.3156,
        'images': ['img1.jpg', 'img2.jpg'],
        'is_featured': true,
        'is_active': true,
      };

      final property = Property.fromJson(json);

      expect(property.id, equals('1'));
      expect(property.propertyType, equals('house'));
      expect(property.listingType, equals('sale'));
      expect(property.titleKu, equals('خانووی تاقیکردنەوە'));
      expect(property.titleAr, equals('منزل تجريبي'));
      expect(property.titleEn, equals('Test House'));
      expect(property.price, equals(100000000));
      expect(property.areaSqm, equals(200));
      expect(property.rooms, equals(3));
      expect(property.bathrooms, equals(2));
      expect(property.address, equals('کەلار'));
      expect(property.ownerName, equals('ئەحمەد'));
      expect(property.ownerPhone, equals('07701234567'));
      expect(property.latitude, equals(34.6189));
      expect(property.longitude, equals(45.3156));
      expect(property.images.length, equals(2));
      expect(property.isFeatured, isTrue);
      expect(property.isActive, isTrue);
    });

    test('typeLabel دەبێت دروست بگەڕێنێتەوە', () {
      final property = Property(
        propertyType: 'house',
        listingType: 'sale',
        titleKu: 'test',
        price: 0,
        address: '',
        ownerName: '',
        ownerPhone: '',
      );

      expect(property.typeLabel, equals('🏠 خانوو'));
    });

    test('typeLabel بۆ جۆرەکانی تر', () {
      final apartment = Property(
        propertyType: 'apartment',
        listingType: 'sale',
        titleKu: 'test',
        price: 0,
        address: '',
        ownerName: '',
        ownerPhone: '',
      );
      expect(apartment.typeLabel, contains('شوقە'));

      final land = Property(
        propertyType: 'land',
        listingType: 'sale',
        titleKu: 'test',
        price: 0,
        address: '',
        ownerName: '',
        ownerPhone: '',
      );
      expect(land.typeLabel, contains('زەوی'));
    });

    test('formattedPrice دەبێت M بۆ ملیۆن بگەڕێنێتەوە', () {
      final property = Property(
        propertyType: 'house',
        listingType: 'sale',
        titleKu: 'test',
        price: 100000000,
        address: '',
        ownerName: '',
        ownerPhone: '',
      );

      expect(property.formattedPrice, contains('M'));
    });

    test('formattedPrice دەبێت K بۆ هەزار بگەڕێنێتەوە', () {
      final property = Property(
        propertyType: 'house',
        listingType: 'sale',
        titleKu: 'test',
        price: 500000,
        address: '',
        ownerName: '',
        ownerPhone: '',
      );

      expect(property.formattedPrice, contains('K'));
    });

    test('hasLocation دەبێت false بگەڕێنێتەوە بێ لۆکەیشن', () {
      final property = Property(
        propertyType: 'house',
        listingType: 'sale',
        titleKu: 'test',
        price: 0,
        address: '',
        ownerName: '',
        ownerPhone: '',
      );

      expect(property.hasLocation, isFalse);
    });

    test('hasLocation دەبێت true بگەڕێنێتەوە لەگەڵ لۆکەیشن', () {
      final property = Property(
        propertyType: 'house',
        listingType: 'sale',
        titleKu: 'test',
        price: 0,
        address: '',
        ownerName: '',
        ownerPhone: '',
        latitude: 34.6189,
        longitude: 45.3156,
      );

      expect(property.hasLocation, isTrue);
    });
  });
}