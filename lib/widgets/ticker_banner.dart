// lib/widgets/ticker_banner.dart
//
// 📺 توڵی هەواڵی بەپەلە — بارێکی سوور لەژێر پەیجی سەرەکیدا.
// • کوردی/عەرەبی/فارسی: دەق لە چەپەوە بۆ ڕاست دەجوڵێت.
// • ئینگلیزی: لە ڕاستەوە بۆ چەپ.
// • کرتەی لێبکرێت → دایەلۆگی هەواڵی بەپەلە دەکرێتەوە.
// • بێ تووڵی چالاک خۆی دەشارێتەوە.

import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/ticker_service.dart';

const _red = Color(0xFFB71C1C);
const _redDark = Color(0xFF7B0000);

/// بۆ ئەوەی دایەلۆگەکە تەنها جارێک لە هەر کردنەوەی ئەپدا بە خۆکار دەربکەوێت
bool _dialogShownThisLaunch = false;

/// دایەلۆگی جوانی هەواڵی بەپەلە پیشان دەدات
Future<void> showBreakingNewsDialog(
  BuildContext context,
  List<NewsTicker> tickers,
) {
  final lang = AppLang.code;
  final items = tickers
      .map((t) => t.textFor(lang).trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (items.isEmpty) return Future.value();
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Directionality(
      textDirection: AppLang.direction,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: _BreakingDialog(items: items),
      ),
    ),
  );
}

class _BreakingDialog extends StatefulWidget {
  final List<String> items;
  const _BreakingDialog({required this.items});

  @override
  State<_BreakingDialog> createState() => _BreakingDialogState();
}

class _BreakingDialogState extends State<_BreakingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.35),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── سەرپەڕ ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_redDark, _red, Color(0xFFD32F2F)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.15).animate(_pulse),
                  child: const Text('⚡', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('هەواڵی بەپەلە'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── ناوەڕۆک ──
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 20,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (_, i) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: _red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.items[i],
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── دوگمەی داخستن ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  tr('تێگەیشتم'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════

class TickerBannerWidget extends StatefulWidget {
  /// بۆ تێست؛ ئەگەر نەدرا لە Supabase دەهێنرێت
  final Future<List<NewsTicker>> Function()? loader;

  /// کاتی کردنەوەی ئەپ دایەلۆگەکە بە خۆکار دەربکەوێت (تەنها جارێک)
  final bool autoDialog;

  const TickerBannerWidget({super.key, this.loader, this.autoDialog = true});

  @override
  State<TickerBannerWidget> createState() => _TickerBannerWidgetState();
}

class _TickerBannerWidgetState extends State<TickerBannerWidget>
    with SingleTickerProviderStateMixin {
  static const _height = 48.0;
  static const _pixelsPerSecond = 55.0;
  static const _style = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  late final AnimationController _ctrl = AnimationController(vsync: this);
  Timer? _refreshTimer;
  List<NewsTicker> _tickers = [];
  String _text = '';

  @override
  void initState() {
    super.initState();
    _load(first: true);
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    final tickers = await (widget.loader ?? TickerService.fetchActive)();
    if (!mounted) return;
    final lang = AppLang.code;
    final text = tickers
        .map((t) => t.textFor(lang).trim())
        .where((s) => s.isNotEmpty)
        .join('      ◆      ');
    setState(() {
      _tickers = tickers;
      _text = text;
    });
    if (text.isEmpty) _ctrl.stop();

    // دایەلۆگی خۆکار — تەنها جارێک لە هەر کردنەوەی ئەپدا
    if (first &&
        widget.autoDialog &&
        !_dialogShownThisLaunch &&
        text.isNotEmpty) {
      _dialogShownThisLaunch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showBreakingNewsDialog(context, _tickers);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_text.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => showBreakingNewsDialog(context, _tickers),
      child: Container(
        height: _height,
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_redDark, _red, Color(0xFFC62828)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _red.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── نیشانەی «هەواڵی بەپەلە» ──
            Container(
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _redDark,
                border: Border(
                  right: BorderSide(color: Color(0x55FFFFFF), width: 1),
                  left: BorderSide(color: Color(0x55FFFFFF), width: 1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 5),
                  Text(
                    tr('هەواڵی بەپەلە'),
                    textDirection: AppLang.direction,
                    style: _style.copyWith(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Expanded(child: _marquee(context)),
          ],
        ),
      ),
    );
  }

  Widget _marquee(BuildContext context) {
    final direction = AppLang.direction;
    final isEnglish = AppLang.code == 'en';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final painter = TextPainter(
          text: TextSpan(text: _text, style: _style),
          textDirection: direction,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final textWidth = painter.width;
        painter.dispose();

        final travel = width + textWidth;
        final duration = Duration(
          milliseconds: (travel / _pixelsPerSecond * 1000).round(),
        );
        if (_ctrl.duration != duration || !_ctrl.isAnimating) {
          _ctrl.duration = duration;
          _ctrl.repeat();
        }

        // SizedBox بە پانییەکی دیاریکراو → شێوەی پیتەکان تێک ناچێت
        final content = SizedBox(
          width: textWidth,
          child: Text(
            _text,
            key: const ValueKey('ticker-text'),
            maxLines: 1,
            softWrap: false,
            textDirection: direction,
            style: _style,
          ),
        );

        return ClipRect(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              // ئینگلیزی: ڕاست → چەپ  |  کوردی/عەرەبی/فارسی: چەپ → ڕاست
              final dx = isEnglish
                  ? width - _ctrl.value * travel
                  : -textWidth + _ctrl.value * travel;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              );
            },
            child: OverflowBox(
              minWidth: 0,
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: content,
            ),
          ),
        );
      },
    );
  }
}
