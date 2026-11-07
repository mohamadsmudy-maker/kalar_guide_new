// lib/utils/label_marker_helper.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 🏷️ یاریدەدەر بۆ دروستکردنی Marker ی تایبەت — Ultra Pro Max
class LabelMarkerHelper {
  LabelMarkerHelper._();

  // ═══════════════════════════════════════════════════════════
  // 🎨 createLabelMarker
  // ═══════════════════════════════════════════════════════════
  static Future<BitmapDescriptor> createLabelMarker({
    required String text,
    Color textColor = Colors.white,
    Color backgroundColor = Colors.blue,
    double fontSize = 26,
    double padding = 14,
    double borderRadius = 20,
    Color borderColor = Colors.white,
    double borderWidth = 3,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ═══ Text ═══
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

    // ═══ قەبارە ═══
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
      Colors.black.withValues(alpha: 0.5),
      8,
      true,
    );

    // باکگراوند
    canvas.drawRRect(rrect, Paint()..color = backgroundColor);

    // چوارچێوە
    if (borderWidth > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }

    // ═══ Text ═══
    textPainter.paint(canvas, Offset(padding, padding));

    // ═══ گۆڕین بۆ Image ═══
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // ═══════════════════════════════════════════════════════════
  // 🏘️ createNeighborhoodLabel
  // ═══════════════════════════════════════════════════════════
  static Future<BitmapDescriptor> createNeighborhoodLabel({
    required String name,
    required Color color,
    double fontSize = 26,
    bool isSelected = false,
  }) async {
    return createLabelMarker(
      text: name,
      textColor: Colors.white,
      backgroundColor: isSelected ? Colors.red.shade700 : color,
      fontSize: isSelected ? 30 : fontSize,
      padding: 12,
      borderRadius: 22,
      borderColor: Colors.white,
      borderWidth: isSelected ? 4 : 2,
    );
  }
}