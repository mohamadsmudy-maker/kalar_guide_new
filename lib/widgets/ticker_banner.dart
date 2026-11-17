// lib/widgets/ticker_banner.dart
//
// 📺 توڵی هەواڵی بەپەلە — بارێکی سوور لەژێر پەیجی سەرەکیدا.
// • کوردی/عەرەبی/فارسی: دەق لە چەپەوە بۆ ڕاست دەجوڵێت.
// • ئینگلیزی: لە ڕاستەوە بۆ چەپ.
// • کرتەی لێبکرێت → دایەلۆگی هەواڵی بەپەلە دەکرێتەوە.
// • بێ تووڵی چالاک خۆی دەشارێتەوە.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/tr.dart';
import '../services/ticker_service.dart';

const _red = Color(0xFFB71C1C);
const _redDark = Color(0xFF7B0000);

/// کلیلی ئەو هەواڵانەی کە پێشتر بە خۆکار پیشان دراون (SharedPreferences)
const _seenKey = 'breaking_news_seen';

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
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // ── کارت ──
        Container(
          margin: const EdgeInsets.only(top: 34),
          padding: const EdgeInsets.fromLTRB(18, 50, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('هەواڵی بەپەلە'),
                style: const TextStyle(
                  color: _red,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFAD4D4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.only(top: 1),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: _red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              AppLang.localDigits('${i + 1}', AppLang.code),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              items[i],
                              style: const TextStyle(
                                fontSize: 15.5,
                                height: 1.6,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    tr('تێگەیشتم'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── نیشانەی سەرەوە (لەسەر لێواری کارتەکە) ──
        Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
              opacity: Tween(begin: 0.55, end: 0.0).animate(_pulse),
              child: ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.35).animate(_pulse),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
                ),
              ),
            ),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), _redDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFFFFD54F), size: 36),
            ),
          ],
        ),
        // ── داخستن ──
        PositionedDirectional(
          top: 42,
          end: 8,
          child: IconButton(
            tooltip: tr('داخستن'),
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════

class TickerBannerWidget extends StatefulWidget {
  /// بۆ تێست؛ ئەگەر نەدرا لە Supabase دەهێنرێت
  final Future<List<NewsTicker>> Function()? loader;

  /// دایەلۆگەکە بە خۆکار دەربکەوێت — تەنها کاتێک هەواڵەکان نوێ بن؛ هەمان
  /// هەواڵ دووبارە بە خۆکار پیشان نادرێت (کرتە لە توڵەکە هەر دەیکاتەوە)
  final bool autoDialog;

  const TickerBannerWidget({super.key, this.loader, this.autoDialog = true});

  @override
  State<TickerBannerWidget> createState() => _TickerBannerWidgetState();
}

class _TickerBannerWidgetState extends State<TickerBannerWidget>
    with SingleTickerProviderStateMixin {
  static const _height = 44.0;
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
        .join('      ◆      ');
    setState(() {
      _tickers = tickers;
      _text = text;
    });
    if (text.isEmpty) {
      _ctrl.stop();
      return;
    }
    if (widget.autoDialog) await _autoShowIfNew(tickers);
  }

  /// هەواڵی نوێ (یان گۆڕاو) → دایەلۆگ؛ هەمان هەواڵ → هیچ
  Future<void> _autoShowIfNew(List<NewsTicker> tickers) async {
    final signature = tickers.map((t) => '${t.id}:${t.textKu}').join('|');
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_seenKey) == signature) return;
      await prefs.setString(_seenKey, signature);
    } catch (_) {
      // بێ پاشەکەوت: هەر پیشانی دەدەین
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showBreakingNewsDialog(context, _tickers);
    });
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
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                  const Icon(Icons.bolt_rounded, color: Color(0xFFFFD54F), size: 18),
                  const SizedBox(width: 3),
                  Text(
                    tr('بەپەلە'),
                    textDirection: AppLang.direction,
                    style: _style.copyWith(fontSize: 14, fontWeight: FontWeight.w900),
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
