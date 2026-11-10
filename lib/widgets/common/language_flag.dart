// lib/widgets/common/language_flag.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ئاڵای زمان. ئاڵای کوردستان ئیمۆجی نییە، بۆیە بە دەست دەکێشرێت.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({super.key, required this.languageId, required this.emoji, this.width = 34});

  final String languageId;
  final String emoji;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (languageId != 'ku') {
      return Text(emoji, style: TextStyle(fontSize: width * 0.76));
    }
    return Container(
      width: width,
      height: width * 2 / 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      child: const CustomPaint(painter: KurdistanFlagPainter()),
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
