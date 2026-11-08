// test/services/fuel_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/fuel_service.dart';

void main() {
  group('FuelService helpers', () {
    test('هەموو جۆرەکان key ی جیاوازیان هەیە', () {
      final keys = FuelService.fuelTypes.map((t) => t['key']).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('ناو بەپێی زمان', () {
      expect(FuelService.getNameKu('super'), 'سوپەر');
      expect(FuelService.getNameAr('super'), 'سوبر');
      expect(FuelService.getNameEn('super'), 'Super');
      expect(FuelService.getNameByLang('super', 'fr'), 'سوپەر');
    });

    test('جۆری نەناسراو', () {
      expect(FuelService.getNameKu('unknown'), 'unknown');
      expect(FuelService.getOrder('unknown'), 99);
      expect(FuelService.getUnitName('unknown', 'en'), 'لیتر');
      expect(FuelService.getEmoji('unknown'), '⛽');
      expect(FuelService.isGas('unknown'), isFalse);
    });

    test('ڕیزبەندی و یەکە', () {
      expect(FuelService.getOrder('normal'), lessThan(FuelService.getOrder('super')));
      expect(FuelService.getUnitName('normal', 'en'), 'L');
    });

    test('getFuelTypesForLang هەموو جۆرەکان دەگەڕێنێتەوە', () {
      final list = FuelService.getFuelTypesForLang('en');
      expect(list.length, FuelService.fuelTypes.length);
      expect(list.every((t) => t['name']!.isNotEmpty), isTrue);
    });
  });

  group('ناسینەوەی بەنزینخانە', () {
    test('هەموو ناوەکانی داتابەیس', () {
      expect(FuelService.isStation({'category': 'بەنزینخانەکان'}), isTrue);
      expect(FuelService.isStation({'category': 'سوتەمەنی'}), isTrue);
      expect(FuelService.isStation({'category': 'خزمەتگوزاری', 'sub_category': 'بەنزینخانە'}), isTrue);
      expect(FuelService.isStation({'category': 'خواردن'}), isFalse);
      expect(FuelService.isStation({}), isFalse);
    });

    test('فلتەری Supabase هەردوو ستوون دەگرێتەوە', () {
      final f = FuelService.stationFilter;
      expect(f, contains('category.ilike.*بەنزین*'));
      expect(f, contains('sub_category.ilike.*سوتەمەنی*'));
    });
  });
}
