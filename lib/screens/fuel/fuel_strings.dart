import '../currency/currency_strings.dart';

/// 🌐 دەقەکانی بەشی سووتەمەنی — ئەوەی لێرە نییە لە CurrencyStrings وەردەگیرێت
class FuelStrings {
  FuelStrings._();

  static const Map<String, Map<String, String>> _t = {
    'title': {'ku': 'نرخی سووتەمەنی', 'ar': 'أسعار الوقود', 'en': 'Fuel prices'},
    'cheapest': {'ku': 'هەرزانترین', 'ar': 'الأرخص', 'en': 'Cheapest'},
    'expensive': {'ku': 'گرانترین', 'ar': 'الأغلى', 'en': 'Highest'},
    'saving': {'ku': 'پاشەکەوت', 'ar': 'توفير', 'en': 'Save'},
    'stations': {'ku': 'بەنزینخانە', 'ar': 'محطة', 'en': 'stations'},
    'fuel': {'ku': 'بەنزین', 'ar': 'بنزين', 'en': 'Fuel'},
    'gas': {'ku': 'گاز', 'ar': 'غاز', 'en': 'Gas'},
    'types': {'ku': 'جۆرەکان', 'ar': 'الأنواع', 'en': 'Types'},
    'calculator': {'ku': 'حیسابکەری تێچوون', 'ar': 'حاسبة التكلفة', 'en': 'Cost calculator'},
    'by_amount': {'ku': 'بەپێی بڕ', 'ar': 'حسب الكمية', 'en': 'By amount'},
    'by_budget': {'ku': 'بەپێی پارە', 'ar': 'حسب المبلغ', 'en': 'By budget'},
    'you_pay': {'ku': 'دەدەیت', 'ar': 'تدفع', 'en': 'You pay'},
    'you_get': {'ku': 'وەردەگریت', 'ar': 'تحصل على', 'en': 'You get'},
    'budget': {'ku': 'پارە (دینار)', 'ar': 'المبلغ (دينار)', 'en': 'Budget (IQD)'},
    'tank_full': {'ku': 'پڕکردنی تانکی', 'ar': 'تعبئة الخزان', 'en': 'Full tank'},
    'map': {'ku': 'نەخشە', 'ar': 'الخريطة', 'en': 'Map'},
    'compare': {'ku': 'بەراورد', 'ar': 'مقارنة', 'en': 'Compare'},
    'chart': {'ku': 'چارت', 'ar': 'المخطط', 'en': 'Chart'},
    'directions': {'ku': 'ڕێگا', 'ar': 'الاتجاهات', 'en': 'Directions'},
    'sort_cheap': {'ku': 'هەرزانترین', 'ar': 'الأرخص', 'en': 'Cheapest'},
    'sort_exp': {'ku': 'گرانترین', 'ar': 'الأغلى', 'en': 'Highest'},
    'search_st': {'ku': 'گەڕان بە ناوی بەنزینخانە...', 'ar': 'ابحث باسم المحطة...', 'en': 'Search stations...'},
    'stations_of': {'ku': 'بەنزینخانەکانی', 'ar': 'محطات', 'en': 'Stations for'},
    'no_stations': {'ku': 'هیچ بەنزینخانەیەک نییە بۆ', 'ar': 'لا توجد محطات لـ', 'en': 'No stations for'},
    'more_than_best': {'ku': 'زیاتر لە هەرزانترین', 'ar': 'أكثر من الأرخص', 'en': 'above cheapest'},
    'fuel_types': {'ku': 'جۆرەکانی سووتەمەنی', 'ar': 'أنواع الوقود', 'en': 'Fuel types'},
    'not_found': {'ku': 'بەنزینخانە نەدۆزرایەوە', 'ar': 'لم يتم العثور على المحطة', 'en': 'Station not found'},
  };

  static String of(String lang, String key) {
    final row = _t[key];
    if (row == null) return CurrencyStrings.of(lang, key);
    return row[lang] ?? row['ku'] ?? key;
  }
}
