import 'package:flutter/material.dart';

/// 🎨 ڕەنگەکانی ئەپ - PRO EDITION
class AppColors {
  // ═══════════════════════════════════════════════
  // 🎯 ڕەنگە سەرەکییەکان
  // ═══════════════════════════════════════════════
  static const Color primary = Color(0xFF1E88E5); // شینی سەرەکی
  static const Color secondary = Color(0xFF6C5CE7); // مۆر
  static const Color background = Color(0xFFF5F6FA);
  static const Color text = Color(0xFF1A1A22);

  // ═══════════════════════════════════════════════
  // ✏️ ڕەنگەکانی نووسین
  // ═══════════════════════════════════════════════
  static const Color textPrimary = Color(0xFF1A1A22);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // ═══════════════════════════════════════════════
  // 🎨 ڕەنگە یاریدەدەرەکان
  // ═══════════════════════════════════════════════
  static const Color red = Color(0xFFEF4444);
  static const Color green = Color(0xFF10B981);
  static const Color orange = Color(0xFFF59E0B);
  static const Color yellow = Color(0xFFFCD34D);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color teal = Color(0xFF14B8A6);
  static const Color pink = Color(0xFFEC4899);

  // ═══════════════════════════════════════════════
  // 🎨 ڕەنگە نەرمەکان
  // ═══════════════════════════════════════════════
  static Color primarySoft = primary.withOpacity(0.10);
  static Color secondarySoft = secondary.withOpacity(0.10);
  static Color redSoft = red.withOpacity(0.10);
  static Color greenSoft = green.withOpacity(0.10);
  static Color orangeSoft = orange.withOpacity(0.10);
  static Color purpleSoft = purple.withOpacity(0.10);

  // ═══════════════════════════════════════════════
  // 🔲 سنوور و جیاکەرەوە
  // ═══════════════════════════════════════════════
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color backgroundGrey = Color(0xFFF5F6FA); // ✅ زیادکرا

  // ═══════════════════════════════════════════════
  // 🌙 Dark Theme Colors
  // ═══════════════════════════════════════════════
  static const Color darkBackground = Color(0xFF0F0F14);
  static const Color darkSurface = Color(0xFF1A1A22);
  static const Color darkCard = Color(0xFF1E1E28);
  static const Color darkBorder = Color(0xFF2A2A35);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B8);
  static const Color darkTextTertiary = Color(0xFF6B6B75);

  // ═══════════════════════════════════════════════
  // 🌈 Gradients (بۆ سلایدەر و کارتەکان)
  // ═══════════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFFE91E63)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ✅ ئەم دوو گرادیێنتە زیادکرا بۆ چارەسەری هەڵەکان
  static const LinearGradient complaintGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient newsGradient = LinearGradient(
    colors: [Color(0xFF1E88E5), Color(0xFF00BCD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════════
  // 🏷️ ڕەنگەکانی بەشەکان (Categories)
  // ✅ ئەم ڕەنگانە زیادکرا بۆ چارەسەری هەڵەکانی home_screen
  // ═══════════════════════════════════════════════
  static const Color catHealth = Color(0xFFEF4444);      // تەندروستی - سوور
  static const Color catEducation = Color(0xFF1E88E5);   // پەروەردە - شین
  static const Color catGovernment = Color(0xFF8B5CF6);  // بەڕێوەبەرایەتی - مۆر
  static const Color catHigherEd = Color(0xFF10B981);    // خوێندنی باڵا - سەوز
  static const Color catFood = Color(0xFFF59E0B);        // خواردن - نارنجی
  static const Color catShopping = Color(0xFFEC4899);    // بازاڕگەری - پەمەیی
}