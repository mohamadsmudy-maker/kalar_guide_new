// 📁 models/emergency_categories.dart
import 'package:flutter/material.dart';

/// 📋 جۆرەکانی فریاکەوتن — Single Source of Truth
///
/// Strong-typed, translated, and safe to use in UI.
@immutable
class EmergencyCategory {
  final String key;
  final String nameKu;
  final String nameAr;
  final String nameEn;
  final String icon;
  final Color color;

  const EmergencyCategory({
    required this.key,
    required this.nameKu,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    required this.color,
  });

  String getName(String lang) {
    switch (lang) {
      case 'ar':
        return nameAr;
      case 'en':
        return nameEn;
      default:
        return nameKu;
    }
  }

  IconData get iconData => _iconFor(icon);
}

/// 🎨 Icon name → IconData lookup (extend as needed)
IconData _iconFor(String name) {
  switch (name) {
    case 'local_police':
      return Icons.local_police;
    case 'local_fire_department':
      return Icons.local_fire_department;
    case 'local_hospital':
      return Icons.local_hospital;
    case 'electric_bolt':
      return Icons.electric_bolt;
    case 'water_drop':
      return Icons.water_drop;
    case 'phone_in_talk':
      return Icons.phone_in_talk;
    case 'apps':
      return Icons.apps;
    case 'emergency':
    default:
      return Icons.emergency;
  }
}

/// 🗂️ All categories — the one and only list.
class EmergencyCategories {
  EmergencyCategories._();

  static const List<EmergencyCategory> all = [
    EmergencyCategory(
      key: 'all',
      nameKu: 'هەموو',
      nameAr: 'الكل',
      nameEn: 'All',
      icon: 'apps',
      color: Color(0xFF64748B),
    ),
    EmergencyCategory(
      key: 'police',
      nameKu: 'پۆلیس',
      nameAr: 'الشرطة',
      nameEn: 'Police',
      icon: 'local_police',
      color: Color(0xFF2563EB),
    ),
    EmergencyCategory(
      key: 'fire',
      nameKu: 'ئاگرکوژێنەوە',
      nameAr: 'الإطفاء',
      nameEn: 'Fire',
      icon: 'local_fire_department',
      color: Color(0xFFEF4444),
    ),
    EmergencyCategory(
      key: 'ambulance',
      nameKu: 'ئەمبولانس',
      nameAr: 'الإسعاف',
      nameEn: 'Ambulance',
      icon: 'local_hospital',
      color: Color(0xFFDC2626),
    ),
    EmergencyCategory(
      key: 'hospital',
      nameKu: 'نەخۆشخانە',
      nameAr: 'المستشفى',
      nameEn: 'Hospital',
      icon: 'local_hospital',
      color: Color(0xFF059669),
    ),
    EmergencyCategory(
      key: 'power',
      nameKu: 'کارەبا',
      nameAr: 'الكهرباء',
      nameEn: 'Power',
      icon: 'electric_bolt',
      color: Color(0xFFF59E0B),
    ),
    EmergencyCategory(
      key: 'water',
      nameKu: 'ئاو',
      nameAr: 'المياه',
      nameEn: 'Water',
      icon: 'water_drop',
      color: Color(0xFF0EA5E9),
    ),
    EmergencyCategory(
      key: 'utility',
      nameKu: 'خزمەتگوزاری',
      nameAr: 'الخدمات',
      nameEn: 'Utility',
      icon: 'electric_bolt',
      color: Color(0xFF8B5CF6),
    ),
    EmergencyCategory(
      key: 'other',
      nameKu: 'گشتی',
      nameAr: 'عام',
      nameEn: 'Other',
      icon: 'phone_in_talk',
      color: Color(0xFF64748B),
    ),
  ];

  /// ✅ Safe lookup — never throws.
  static EmergencyCategory? getByKey(String key) {
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }

  /// ✅ Get-or-fallback. Useful for UI when category is unknown.
  static EmergencyCategory getOrOther(String? key) {
    if (key == null || key.isEmpty) return _other;
    return getByKey(key) ?? _other;
  }

  static EmergencyCategory get _other => all.firstWhere(
        (c) => c.key == 'other',
    orElse: () => const EmergencyCategory(
      key: 'other',
      nameKu: 'گشتی',
      nameAr: 'عام',
      nameEn: 'Other',
      icon: 'phone_in_talk',
      color: Color(0xFF64748B),
    ),
  );

  /// 🌐 Localized category name for an arbitrary key.
  static String getName(String key, String lang) {
    return getOrOther(key).getName(lang);
  }

  /// 🚫 Categories that should NOT appear as filter chips.
  static List<EmergencyCategory> get filterable =>
      all.where((c) => c.key != 'all').toList();

  /// 🚫 Categories that can be selected on an item (exclude `all`).
  static List<EmergencyCategory> get selectable => filterable;
}