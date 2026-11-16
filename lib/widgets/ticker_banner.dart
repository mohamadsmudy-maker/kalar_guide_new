// lib/widgets/ticker_banner.dart
//
// 📺 توڵی هەواڵی بەپەلە — TV-style red scrolling marquee.
// Auto-hides when no active tickers; fetches on first build.

import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/ticker_service.dart';

class TickerBannerWidget extends StatefulWidget {
  const TickerBannerWidget({super.key});

  @override
  State<TickerBannerWidget> createState() => _TickerBannerWidgetState();
}

class _TickerBannerWidgetState extends State<TickerBannerWidget>
    with SingleTickerProviderStateMixin {
  List<NewsTicker> _tickers = [];
  bool _loaded = false;
  String _fullText = '';
  late AnimationController _ctrl;
  Timer? _refreshTimer;
  static const _tickerHeight = 42.0;
  static const _charsPerSec = 7.0; // scrolling speed

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _load();
    // refresh every 2 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) => _load());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final tickers = await TickerService.fetchActive();
    if (!mounted) return;
    setState(() {
      _tickers = tickers;
      _loaded = true;
      _buildText();
    });
  }

  void _buildText() {
    if (_tickers.isEmpty) {
      _ctrl.stop();
      return;
    }
    final lang = AppLang.code;
    final parts = _tickers.map((t) => t.textFor(lang)).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) {
      _ctrl.stop();
      return;
    }
    _fullText = parts.join('   ⬥   ');
    final seconds = (_fullText.length / _charsPerSec).clamp(10.0, 300.0);
    _ctrl.duration = Duration(milliseconds: (seconds * 1000).round());
    _ctrl.repeat();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _tickers.isEmpty || _fullText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: _tickerHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFB71C1C), Color(0xFFC62828)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66B71C1C),
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Label badge ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF7B0000),
              border: Border(
                right: BorderSide(color: Color(0x55FFFFFF), width: 1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚡', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  tr('هەواڵی بەپەلە'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // ── Scrolling text ─────────────────────────────────
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textWidth = _measureText(_fullText);
                  return AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      final total = constraints.maxWidth + textWidth;
                      // text enters from right: start = containerWidth, end = -textWidth
                      final offset = constraints.maxWidth - _ctrl.value * total;
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: Text(
                          _fullText,
                          softWrap: false,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _measureText(String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return tp.width;
  }
}
