// lib/widgets/common/language_flag.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// نیشانەی زمان: پیتی یەکەمی ناوی زمانەکە بە خۆی (نەک ئاڵای وڵات).
/// ئاڵا بۆ زمان هەڵەیەکی ناسراوی دیزاینە و هەستیاریی سیاسیشی هەیە.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({super.key, required this.languageId, this.emoji = '', this.width = 34});

  final String languageId;

  /// کۆن؛ ئێستا بەکارنایەت
  final String emoji;
  final double width;

  static const _labels = {'ku': 'کو', 'ar': 'ع', 'fa': 'ف', 'en': 'En'};
  static const _colors = {
    'ku': Color(0xFF1E88E5),
    'ar': Color(0xFF0F9D7A),
    'fa': Color(0xFF7C3AED),
    'en': Color(0xFFD9822B),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[languageId] ?? const Color(0xFF64748B);
    return Container(
      width: width,
      height: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Text(
        _labels[languageId] ?? languageId.toUpperCase(),
        textDirection: languageId == 'en' ? TextDirection.ltr : TextDirection.rtl,
        style: TextStyle(color: color, fontSize: width * 0.38, fontWeight: FontWeight.w900, height: 1),
      ),
    );
  }
}

/// ئاڵای کوردستان: سوور، سپی، سەوز + خۆری زەردی ٢١ تیشک
class KurdistanFlagPainter extends CustomPainter {
  const KurdistanFlagPainter();

  static const _red = Color(0xFFED2024);
  static const _green = Color(0xFF278E43);
  static const _sun = Color(0xFFFEBD11);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, band = h / 3;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, band), Paint()..color = _red);
    canvas.drawRect(Rect.fromLTWH(0, band, w, band), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(0, band * 2, w, h - band * 2), Paint()..color = _green);

    // خۆر: ٢١ تیشک، تیرەی نزیکەی ٣٣٪ ی بەرزی ئاڵا
    final c = Offset(w / 2, h / 2);
    final outer = h * 0.33, inner = outer * 0.62;
    const rays = 21;
    final path = Path();
    for (var i = 0; i < rays * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / rays;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = _sun);
  }

  @override
  bool shouldRepaint(KurdistanFlagPainter oldDelegate) => false;
}
