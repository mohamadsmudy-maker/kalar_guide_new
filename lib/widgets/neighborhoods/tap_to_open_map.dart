import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/tr.dart';

/// 🗺️ نەخشەی پێشاندان لەناو لاپەڕەیەکی سکرۆڵکراو.
///
/// نەخشەکە جووڵە ناکات و گوێ لە پەنجە ناگرێت، بۆیە لاپەڕەکە ئاسایی سکرۆڵ دەبێت
/// (پێشتر نەخشەکە پەنجەی دەگرت و سکرۆڵی ڕادەگرت). کاتێک بەکارهێنەر دەست لێ دەدات،
/// دوگمەی «کردنەوەی نەخشە» دەردەکەوێت؛ بە کلیک لەسەر دوگمەکە نەخشە گەورەکە دەکرێتەوە.
/// دوگمەکە دوای چەند چرکەیەک خۆی دەشارێتەوە.
class TapToOpenMap extends StatefulWidget {
  /// خودی نەخشەکە — ئینتەراکتیڤ نەبێت
  final Widget map;
  final VoidCallback onOpen;
  final Color color;
  final double height;
  final Duration hideAfter;

  const TapToOpenMap({
    super.key,
    required this.map,
    required this.onOpen,
    required this.color,
    this.height = 240,
    this.hideAfter = const Duration(seconds: 4),
  });

  @override
  State<TapToOpenMap> createState() => _TapToOpenMapState();
}

class _TapToOpenMapState extends State<TapToOpenMap> {
  bool _showButton = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    _timer?.cancel();
    final show = !_showButton;
    setState(() => _showButton = show);
    if (show) {
      HapticFeedback.selectionClick();
      _timer = Timer(widget.hideAfter, () {
        if (mounted) setState(() => _showButton = false);
      });
    }
  }

  void _open() {
    _timer?.cancel();
    setState(() => _showButton = false);
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : widget.color.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // نەخشەکە پەنجە ناگرێت: سکرۆڵی لاپەڕەکە بەسەریدا تێدەپەڕێت
            IgnorePointer(child: widget.map),

            // تەنها کلیک (نەک ڕاکێشان)، بۆیە ڕاکێشان بۆ سکرۆڵی لاپەڕەکەیە
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  color: Colors.black.withValues(alpha: _showButton ? 0.18 : 0),
                ),
              ),
            ),

            Center(
              child: IgnorePointer(
                ignoring: !_showButton,
                child: AnimatedScale(
                  scale: _showButton ? 1 : 0.85,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _showButton ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: ElevatedButton.icon(
                      onPressed: _open,
                      icon: const Icon(Icons.open_in_full_rounded, size: 18),
                      label: Text(
                        tr('کردنەوەی نەخشە'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.color,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
