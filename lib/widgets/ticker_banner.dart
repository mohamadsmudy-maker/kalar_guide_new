// lib/widgets/ticker_banner.dart
//
// 📺 توڵی هەواڵی بەپەلە — دەقی سوور لە چەپەوە بۆ ڕاست دەجوڵێت وەک تەلەفزیۆن.
// کاتێک هیچ تووڵێکی چالاک نییە خۆی دەشارێتەوە.

import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/ticker_service.dart';

class TickerBannerWidget extends StatefulWidget {
  /// بۆ تێست؛ ئەگەر نەدرا لە Supabase دەهێنرێت
  final Future<List<NewsTicker>> Function()? loader;

  const TickerBannerWidget({super.key, this.loader});

  @override
  State<TickerBannerWidget> createState() => _TickerBannerWidgetState();
}

class _TickerBannerWidgetState extends State<TickerBannerWidget>
    with SingleTickerProviderStateMixin {
  static const _height = 42.0;
  static const _pixelsPerSecond = 55.0;
  static const _textStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  late final AnimationController _ctrl = AnimationController(vsync: this);
  Timer? _refreshTimer;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tickers = await (widget.loader ?? TickerService.fetchActive)();
    if (!mounted) return;
    final lang = AppLang.code;
    final text = tickers
        .map((t) => t.textFor(lang).trim())
        .where((s) => s.isNotEmpty)
        .join('   ◆   ');
    if (text == _text) return;
    setState(() => _text = text);
    if (text.isEmpty) _ctrl.stop();
  }

  @override
  Widget build(BuildContext context) {
    if (_text.isEmpty) return const SizedBox.shrink();

    return Container(
      height: _height,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFB71C1C), width: 2)),
        boxShadow: [
          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      // ئاڕاستەی جوڵە هەمیشە چەپ ← ڕاستە، بێ گوێدانە زمانی ئەپ
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(child: ClipRect(child: _marquee(context))),
            Container(
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              color: const Color(0xFFB71C1C),
              child: Text(
                tr('هەواڵی بەپەلە'),
                textDirection: AppLang.direction,
                style: _textStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _marquee(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(_textStyle).copyWith(
          color: const Color(0xFFC62828),
        );
    final direction = AppLang.direction;

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: _text, style: style),
          textDirection: direction,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final textWidth = painter.width;
        painter.dispose();

        final travel = constraints.maxWidth + textWidth;
        final duration = Duration(milliseconds: (travel / _pixelsPerSecond * 1000).round());
        if (_ctrl.duration != duration || !_ctrl.isAnimating) {
          _ctrl.duration = duration;
          _ctrl.repeat();
        }

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Transform.translate(
            // لە دەرەوەی لای چەپەوە دێتە ژوور و لە لای ڕاستەوە دەچێتە دەر
            offset: Offset(-textWidth + _ctrl.value * travel, 0),
            child: child,
          ),
          child: OverflowBox(
            minWidth: 0,
            maxWidth: double.infinity,
            alignment: Alignment.centerLeft,
            child: Text(
              _text,
              key: const ValueKey('ticker-text'),
              maxLines: 1,
              softWrap: false,
              textDirection: direction,
              style: style,
            ),
          ),
        );
      },
    );
  }
}
