import 'package:flutter/material.dart';

/// 🏷️ جۆری وێنەی گەلەری
@immutable
class GalleryCategory {
  final String id;          // key — دەبێت لە DB بەکاربهێنرێت
  final String label;       // ناوی کوردی
  final IconData icon;
  final Color color;

  const GalleryCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}