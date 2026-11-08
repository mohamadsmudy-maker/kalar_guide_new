import 'package:flutter/material.dart';
import 'gallery_category.dart';
import '../../l10n/tr.dart';

/// 📚 ڕیجستری هەموو جۆرەکانی گەلەری
class GalleryCategoryRegistry {
  GalleryCategoryRegistry._();

  static final List<GalleryCategory> all = [
    GalleryCategory(
      id: 'nature',
      label: tr('سروشت'),
      icon: Icons.forest_rounded,
      color: const Color(0xFF2E7D32),
    ),
    GalleryCategory(
      id: 'history',
      label: tr('مێژوو'),
      icon: Icons.account_balance_rounded,
      color: const Color(0xFF6D4C41),
    ),
    GalleryCategory(
      id: 'city',
      label: tr('شار'),
      icon: Icons.location_city_rounded,
      color: const Color(0xFF1565C0),
    ),
    GalleryCategory(
      id: 'events',
      label: tr('بۆنەکان'),
      icon: Icons.celebration_rounded,
      color: const Color(0xFFE65100),
    ),
    GalleryCategory(
      id: 'sports',
      label: tr('وەرزش'),
      icon: Icons.sports_soccer_rounded,
      color: const Color(0xFF00838F),
    ),
    GalleryCategory(
      id: 'culture',
      label: tr('کەلتوور'),
      icon: Icons.theater_comedy_rounded,
      color: const Color(0xFF6A1B9A),
    ),
    GalleryCategory(
      id: 'food',
      label: tr('خواردن'),
      icon: Icons.restaurant_rounded,
      color: const Color(0xFFD84315),
    ),
    GalleryCategory(
      id: 'general',
      label: tr('گشتی'),
      icon: Icons.photo_library_rounded,
      color: const Color(0xFF455A64),
    ),
  ];

  static GalleryCategory byId(String? id) {
    if (id == null || id.isEmpty) return all.last;
    return all.firstWhere(
          (c) => c.id == id,
      orElse: () => all.last,
    );
  }

  static const String defaultId = 'general';
}