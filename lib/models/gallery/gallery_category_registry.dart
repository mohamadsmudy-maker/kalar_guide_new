import 'package:flutter/material.dart';
import 'gallery_category.dart';

/// 📚 ڕیجستری هەموو جۆرەکانی گەلەری
class GalleryCategoryRegistry {
  GalleryCategoryRegistry._();

  static final List<GalleryCategory> all = [
    const GalleryCategory(
      id: 'nature',
      label: 'سروشت', // tr() لە شوێنی پیشاندان
      icon: Icons.forest_rounded,
      color: Color(0xFF2E7D32),
    ),
    const GalleryCategory(
      id: 'history',
      label: 'مێژوو', // tr() لە شوێنی پیشاندان
      icon: Icons.account_balance_rounded,
      color: Color(0xFF6D4C41),
    ),
    const GalleryCategory(
      id: 'city',
      label: 'شار', // tr() لە شوێنی پیشاندان
      icon: Icons.location_city_rounded,
      color: Color(0xFF1565C0),
    ),
    const GalleryCategory(
      id: 'events',
      label: 'بۆنەکان', // tr() لە شوێنی پیشاندان
      icon: Icons.celebration_rounded,
      color: Color(0xFFE65100),
    ),
    const GalleryCategory(
      id: 'sports',
      label: 'وەرزش', // tr() لە شوێنی پیشاندان
      icon: Icons.sports_soccer_rounded,
      color: Color(0xFF00838F),
    ),
    const GalleryCategory(
      id: 'culture',
      label: 'کەلتوور', // tr() لە شوێنی پیشاندان
      icon: Icons.theater_comedy_rounded,
      color: Color(0xFF6A1B9A),
    ),
    const GalleryCategory(
      id: 'food',
      label: 'خواردن', // tr() لە شوێنی پیشاندان
      icon: Icons.restaurant_rounded,
      color: Color(0xFFD84315),
    ),
    const GalleryCategory(
      id: 'general',
      label: 'گشتی', // tr() لە شوێنی پیشاندان
      icon: Icons.photo_library_rounded,
      color: Color(0xFF455A64),
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