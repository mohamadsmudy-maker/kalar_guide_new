// lib/config/app_colors.dart
import 'package:flutter/material.dart';

/// 🎨 ڕەنگەکانی ئەپ — Ultra Pro Max
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════
  // 🎯 ڕەنگی سەرەکی
  // ═══════════════════════════════════════════════════════════
  static const Color primary = Color(0xFF1E88E5);
  static const Color secondary = Color(0xFF4F5BD5); // ئیندیگۆی ئارام
  static const Color background = Color(0xFFF5F6FA);
  static const Color text = Color(0xFF1A1A22);

  // ═══════════════════════════════════════════════════════════
  // ✏️ ڕەنگی نووسین
  // ═══════════════════════════════════════════════════════════
  static const Color textPrimary = Color(0xFF1A1A22);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕەنگی یاریدەدەر
  // ═══════════════════════════════════════════════════════════
  static const Color red = Color(0xFFDC3545);
  static const Color green = Color(0xFF0F9D7A);
  static const Color orange = Color(0xFFD9822B);
  static const Color yellow = Color(0xFFE0B341);
  static const Color purple = Color(0xFF5B5FC7);
  static const Color teal = Color(0xFF0E8C8C);
  static const Color pink = Color(0xFFC2557A);

  static const Color success = Color(0xFF0F9D7A);
  static const Color warning = Color(0xFFD9822B);
  static const Color info = Color(0xFF1E88E5);
  static const Color error = Color(0xFFDC3545);
  static const Color danger = Color(0xFFDC3545);

  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕەنگی نەرم (10% alpha)
  // ═══════════════════════════════════════════════════════════
  static final Color primarySoft = primary.withValues(alpha: 0.10);
  static final Color secondarySoft = secondary.withValues(alpha: 0.10);
  static final Color redSoft = red.withValues(alpha: 0.10);
  static final Color greenSoft = green.withValues(alpha: 0.10);
  static final Color orangeSoft = orange.withValues(alpha: 0.10);
  static final Color yellowSoft = yellow.withValues(alpha: 0.15);
  static final Color purpleSoft = purple.withValues(alpha: 0.10);
  static final Color tealSoft = teal.withValues(alpha: 0.10);
  static final Color pinkSoft = pink.withValues(alpha: 0.10);

  // ═══════════════════════════════════════════════════════════
  // 🔲 سنوور
  // ═══════════════════════════════════════════════════════════
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color backgroundGrey = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color shadow = Color(0x1A000000);

  // ═══════════════════════════════════════════════════════════
  // 🌙 Dark Theme
  // ═══════════════════════════════════════════════════════════
  static const Color darkBackground = Color(0xFF0F0F14);
  static const Color darkSurface = Color(0xFF1A1A22);
  static const Color darkCard = Color(0xFF1E1E28);
  static const Color darkBorder = Color(0xFF2A2A35);
  static const Color darkDivider = Color(0xFF252530);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B8);
  static const Color darkTextTertiary = Color(0xFF6B6B75);
  static const Color darkShadow = Color(0x66000000);

  // ═══════════════════════════════════════════════════════════
  // 🌈 Gradients
  // ═══════════════════════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E88E5), Color(0xFF3F51B5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient complaintGradient = LinearGradient(
    colors: [Color(0xFF4F5BD5), Color(0xFF1E88E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient newsGradient = LinearGradient(
    colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF0F9D7A), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFD9822B), Color(0xFFE0A044)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1A22), Color(0xFF0F0F14)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ═══════════════════════════════════════════════════════════
  // 🏷️ ڕەنگی بەشەکان
  // ═══════════════════════════════════════════════════════════
  static const Color catHealth = Color(0xFF0F9D7A);
  static const Color catEducation = Color(0xFF1E88E5);
  static const Color catGovernment = Color(0xFF4F5BD5);
  static const Color catHigherEd = Color(0xFF0E8C8C);
  static const Color catFood = Color(0xFFD9822B);
  static const Color catShopping = Color(0xFFC2557A);

  static const Map<String, Color> categoryColors = {
    'health': catHealth,
    'education': catEducation,
    'government': catGovernment,
    'higher_ed': catHigherEd,
    'food': catFood,
    'shopping': catShopping,
  };

  static Color categoryColor(String? name) {
    if (name == null) return primary;
    return categoryColors[name.toLowerCase()] ?? primary;
  }

  static Color categoryColorSoft(String? name) {
    return categoryColor(name).withValues(alpha: 0.10);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎛️ پالێتی ئارام — هەموو ڕەنگێکی تیژ دەگۆڕێت بۆ یەکێک لەمانە
  // (شین، ئیندیگۆ، سەوزی تیل، کارەبایی، گوڵی، خۆڵەمێشی) بۆ ئەوەی
  // ئەپەکە یەک ڕووخسار و ئارام بێت. سوور تەنها بۆ فریاکەوتن/هەڵە.
  // ═══════════════════════════════════════════════════════════
  static const Color toneBlue = primary;
  static const Color toneIndigo = Color(0xFF4F5BD5);
  static const Color toneTeal = Color(0xFF0F9D7A);
  static const Color toneAmber = Color(0xFFD9822B);
  static const Color toneRose = Color(0xFFC2557A);
  static const Color toneRed = Color(0xFFDC3545);
  static const Color toneSlate = Color(0xFF5B6B82);

  /// ڕەنگێکی تیژ (بۆ نموونە 0xFFEF4444) → هاوتای ئارامی پالێتەکە
  static Color calm(Color c) {
    final hsv = HSVColor.fromColor(c);
    if (hsv.saturation < 0.18 || hsv.value < 0.18) return toneSlate;
    final h = hsv.hue;
    if (h < 12 || h >= 350) return toneRed;
    if (h < 55) return toneAmber;
    if (h < 175) return toneTeal;
    if (h < 228) return toneBlue;
    if (h < 290) return toneIndigo;
    return toneRose;
  }

  /// باکگراوندی کاڵی ئایکۆن (هەمان ڕەنگ، ١٠٪)
  static Color calmSoft(Color c, {bool dark = false}) =>
      calm(c).withValues(alpha: dark ? 0.18 : 0.10);

  // ═══════════════════════════════════════════════════════════
  // 🌓 Theme-aware helpers
  // ═══════════════════════════════════════════════════════════
  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBackground
          : background;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCard : surface;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : textSecondary;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : border;
}