// lib/utils/place_display.dart
import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../l10n/tr.dart';

/// 🏷️ یارمەتیدەری پیشاندانی شوێن و بەش (ناونیشان، ئایکۆن، ڕەنگ)
class PlaceDisplay {
  PlaceDisplay._();

  // تەنها وشەی تەواو (پیت لە پێش و دوای نییە؛ «،» ڕێگە پێدراوە)
  static final RegExp _kalarTypo = RegExp(r'(?<!\p{L})کلار(?!\p{L})', unicode: true);

  /// ناونیشانی پیشاندراو: بەتاڵ → «کەلار»، هەڵەی «کلار» → «کەلار»
  static String address(Object? raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return 'کەلار';
    return s.replaceAll(_kalarTypo, 'کەلار');
  }

  /// ڕیزبەندی گرنگە: وشەی تایبەت پێش وشەی گشتی
  static const List<(List<String>, IconData, Color)> _rules = [
    (
      ['ئاگرکوژێنەوە', 'بەرگری شارستانی'],
      Icons.local_fire_department_rounded,
      Color(0xFFEF4444)
    ),
    (
      ['پۆلیس', 'ئاسایش', 'هاتوچۆ'],
      Icons.local_police_rounded,
      Color(0xFF1D4ED8)
    ),
    (['فریاکەوتن', 'ئەمبولانس'], Icons.emergency_rounded, Color(0xFFDC2626)),
    (['دەرمانخانە'], Icons.local_pharmacy_rounded, Color(0xFF059669)),
    (
      ['تەندروستی', 'نەخۆشخانە', 'کلینیک', 'پزیشک'],
      Icons.local_hospital_rounded,
      Color(0xFF10B981)
    ),
    (
      ['بەنزین', 'سوتەمەنی', 'سووتەمەنی'],
      Icons.local_gas_station_rounded,
      Color(0xFFF97316)
    ),
    (
      ['وەرزش', 'یاریگا', 'هۆڵ'],
      Icons.sports_soccer_rounded,
      Color(0xFF22C55E)
    ),
    (
      ['خوێندنی باڵا', 'زانکۆ', 'پەیمانگا', 'کۆلێژ'],
      Icons.school_rounded,
      Color(0xFF6366F1)
    ),
    (
      ['پەروەردە', 'قوتابخانە', 'باخچەی ساوایان'],
      Icons.menu_book_rounded,
      Color(0xFF8B5CF6)
    ),
    (
      ['ڕاگەیاندن', 'پەیوەندی', 'ڕادیۆ', 'تەلەفزیۆن', 'دەنگی'],
      Icons.podcasts_rounded,
      Color(0xFF0EA5E9)
    ),
    (['ڕێکخراو'], Icons.diversity_3_rounded, Color(0xFFEC4899)),
    (['مێوانخانە', 'هوتێل'], Icons.hotel_rounded, Color(0xFF14B8A6)),
    (
      ['چێشتخانە', 'خواردن', 'ڕێستۆرانت', 'شیرینی'],
      Icons.restaurant_rounded,
      Color(0xFFF59E0B)
    ),
    (['کافێ', 'قاوە', 'چایخانە'], Icons.local_cafe_rounded, Color(0xFF92400E)),
    (
      ['بانک', 'دراو', 'سەرافی', 'نوسینگەی دراو'],
      Icons.account_balance_wallet_rounded,
      Color(0xFF16A34A)
    ),
    (['مزگەوت', 'ئاینی', 'ئایینی'], Icons.mosque_rounded, Color(0xFF0D9488)),
    (
      ['پارک', 'باخچە', 'گەشت', 'شوێنەگشتی', 'شوێنە گشتی'],
      Icons.park_rounded,
      Color(0xFF16A34A)
    ),
    (['گۆڕستان'], Icons.yard_rounded, Color(0xFF64748B)),
    (
      ['ئیدارە', 'ئیدارەی گەرمیان', 'حکومەت'],
      Icons.account_balance_rounded,
      Color(0xFF2563EB)
    ),
    (
      ['شارەوانی', 'قایمقام', 'سەرۆکایەتی', 'پارێزگا'],
      Icons.account_balance_rounded,
      Color(0xFF2563EB)
    ),
    (
      ['فەرمانگە', 'بەڕێوەبەرایەتی', 'حکومی'],
      Icons.apartment_rounded,
      Color(0xFF3B82F6)
    ),
    (['حزب', 'پارت', 'بارەگا'], Icons.flag_rounded, Color(0xFF7C3AED)),
    (
      ['بازاڕ', 'دوکان', 'مۆڵ', 'فرۆشگا'],
      Icons.shopping_bag_rounded,
      Color(0xFFE91E63)
    ),
  ];

  /// ڕەنگەکانی سەرەوە دەگۆڕدرێن بۆ پالێتی ئارامی ئەپ (AppColors.calm)
  static (IconData, Color) _match(String text) {
    final n = text.trim();
    for (final (words, icon, color) in _rules) {
      if (words.any(n.contains)) return (icon, AppColors.calm(color));
    }
    return (Icons.storefront_rounded, AppColors.toneSlate);
  }

  /// ئایکۆن بەپێی ناوی بەش (یان ناوی شوێن)
  static IconData icon(String text) => _match(text).$1;

  /// ڕەنگ بەپێی ناوی بەش
  static Color color(String text) => _match(text).$2;

  /// بەشە گشتییەکان (فەرمانگە، بازاڕ...) — ناوی شوێن وردترە لەمانە
  static final Set<IconData> _generic = {
    Icons.storefront_rounded,
    Icons.apartment_rounded,
    Icons.shopping_bag_rounded,
    Icons.account_balance_rounded,
  };

  /// ناوی شوێن یەکەمە ئەگەر تایبەت بێت (بنکەی ئاگرکوژێنەوە، پۆلیس...)،
  /// ئەگەرنا بەشەکەی
  static (IconData, Color) _forPlace(Map<String, dynamic> place) {
    final byName = _match('${place['name'] ?? ''}');
    if (!_generic.contains(byName.$1)) return byName;
    final byCat =
        _match('${place['category'] ?? ''} ${place['sub_category'] ?? ''}');
    if (byCat.$1 != Icons.storefront_rounded) return byCat;
    return byName;
  }

  static IconData iconForPlace(Map<String, dynamic> place) =>
      _forPlace(place).$1;

  static Color colorForPlace(Map<String, dynamic> place) => _forPlace(place).$2;

  /// دووری بە کیلۆمەتر → «٣٢٨ م» / «٢.٣ کم» ؛ null یان نەزانراو → null
  static String? distance(double? km, {bool kurdishDigits = true}) {
    if (km == null || km.isNaN || km >= 9999) return null;
    final text =
        km < 1 ? '${(km * 1000).round()} م' : '${km.toStringAsFixed(1)} کم';
    if (!kurdishDigits) return text;
    return _toKu(text);
  }

  /// ئایا شوێنەکە سەر بەم بەشەیە؟ category یان sub_category، بە
  /// ئاسایی‌کردنی «ي/ك»، ZWNJ و بۆشایی (هەمان شت لە ژمارەکردن و لیستدا)
  static bool inCategory(Map<String, dynamic> store, String categoryName) {
    final want = AppLang.normalizeKey(categoryName);
    if (want.isEmpty) return false;
    for (final f in const ['category', 'sub_category']) {
      final v = AppLang.normalizeKey('${store[f] ?? ''}');
      if (v.isNotEmpty && v.contains(want)) return true;
    }
    return false;
  }

  /// ژمارە بە پیتی زمانی ئێستا: کوردی/عەرەبی → «١٤١»، ئینگلیزی → «141»
  static String digits(Object n) => AppLang.isRtl ? _toKu('$n') : '$n';

  static String _toKu(String s) {
    const ku = '٠١٢٣٤٥٦٧٨٩';
    return s.replaceAllMapped(RegExp(r'\d'), (m) => ku[int.parse(m[0]!)]);
  }
}
