// 📁 models/emergency_categories.dart
/// 📋 جۆرەکانی فریاکەوتن — Single Source of Truth
class EmergencyCategories {
  EmergencyCategories._();

  static const List<Map<String, String>> categories = [
    {'key': 'all', 'name': 'هەموو', 'icon': 'apps'},
    {'key': 'police', 'name': 'پۆلیس', 'icon': 'local_police'},
    {'key': 'fire', 'name': 'ئاگرکوژێنەوە', 'icon': 'local_fire_department'},
    {'key': 'ambulance', 'name': 'ئەمبولانس', 'icon': 'local_hospital'},
    {'key': 'hospital', 'name': 'نەخۆشخانە', 'icon': 'local_hospital'},
    {'key': 'power', 'name': 'کارەبا', 'icon': 'electric_bolt'},
    {'key': 'water', 'name': 'ئاو', 'icon': 'water_drop'},
    {'key': 'utility', 'name': 'خزمەتگوزاری', 'icon': 'electric_bolt'},
    {'key': 'other', 'name': 'گشتی', 'icon': 'phone_in_talk'},
  ];

  /// وەرگرتنی کاتێگۆری بە key
  static Map<String, String>? getByKey(String key) {
    try {
      return categories.firstWhere((c) => c['key'] == key);
    } catch (_) {
      return null;
    }
  }

  /// وەرگرتنی ناوی کاتێگۆری بەپێی زمان
  static String getName(String key, String lang) {
    final cat = getByKey(key);
    if (cat == null) return key;

    // ✅ لە ئایندەدا دەتوانرێت وەرگێڕان زیاد بکرێت
    switch (lang) {
      case 'ar':
      // دەتوانیت ناوی عەرەبی زیاد بکەیت لێرە
        return cat['name']!;
      case 'en':
      // دەتوانیت ناوی ئینگلیزی زیاد بکەیت لێرە
        return cat['name']!;
      default:
        return cat['name']!;
    }
  }
}