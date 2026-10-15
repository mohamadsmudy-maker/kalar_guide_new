// lib/utils/label_marker_helper.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 🏷️ یاریدەدەر بۆ دروستکردنی Marker ی تایبەت بە ناوی گەڕەک
class LabelMarkerHelper {
  /// دروستکردنی BitmapDescriptor لە Text
  static Future<BitmapDescriptor> createLabelMarker({
    required String text,
    Color textColor = Colors.black,
    Color backgroundColor = Colors.white,
    double fontSize = 28,
    double padding = 12,
    double borderRadius = 16,
    Color borderColor = Colors.transparent,
    double borderWidth = 2,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ═══ پێکهاتەی Text ═══
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: textColor,
          fontFamily: 'Rabar',
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );

    textPainter.layout(maxWidth: 500);

    // ═══ قەبارەی Label ═══
    final width = textPainter.width + (padding * 2);
    final height = textPainter.height + (padding * 2);

    // ═══ باکگراوند ═══
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, height),
      Radius.circular(borderRadius),
    );

    // سێبەر
    canvas.drawShadow(
      Path()..addRRect(rrect),
      Colors.black.withValues(alpha: 0.4),
      6,
      false,
    );

    // باکگراوند
    canvas.drawRRect(
      rrect,
      Paint()..color = backgroundColor,
    );

    // چوارچێوە
    if (borderWidth > 0 && borderColor != Colors.transparent) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }

    // ═══ Text ═══
    textPainter.paint(
      canvas,
      Offset(padding, padding),
    );

    // ═══ گۆڕین بۆ Image ═══
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  /// دروستکردنی Label بۆ گەڕەک بە ڕەنگی تایبەت ⭐
  static Future<BitmapDescriptor> createNeighborhoodLabel({
    required String name,
    required Color color,
    double fontSize = 26,
    bool isSelected = false,   // ⭐ زیادکرا
  }) async {
    return createLabelMarker(
      text: name,
      textColor: Colors.white,
      backgroundColor: isSelected ? Colors.red.shade700 : color,
      fontSize: fontSize,
      padding: 10,
      borderRadius: 20,
      borderColor: Colors.white,
      borderWidth: isSelected ? 3 : 2,
    );
  }
}