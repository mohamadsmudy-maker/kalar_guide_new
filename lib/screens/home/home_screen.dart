// lib/screens/home/home_screen.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:provider/provider.dart';

import 'package:kalar_guide_new/config/app_colors.dart';
import 'package:kalar_guide_new/config/settings_provider.dart';
import 'package:kalar_guide_new/config/translations.dart';
import 'package:kalar_guide_new/providers/news_providers.dart';
import 'package:kalar_guide_new/services/analytics_service.dart';
import 'package:kalar_guide_new/widgets/carousels/news_carousel.dart';
import 'package:kalar_guide_new/screens/complaints/complaint_instruction_dialog.dart';
import 'package:kalar_guide_new/screens/neighborhoods/neighborhoods_screen.dart';
import 'package:kalar_guide_new/screens/map_screen.dart';
import 'package:kalar_guide_new/screens/news/news_details.dart';
import 'package:kalar_guide_new/screens/news/all_news_screen.dart';
import 'package:kalar_guide_new/screens/gallery/gallery_screen.dart';
import '../../l10n/tr.dart';

const double _kBackToTopOffset = 600;
const int _kCarouselCount = 5;
const int _kListCount = 10;
const int _kPrecacheCount = 3;

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onSearchTap;

  const HomeScreen({super.key, this.onMenuTap, this.onSearchTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _showTop = ValueNotifier<bool>(false);

  final Set<String> _precached = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheImages(ref.read(newsProvider).news);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _showTop.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scroll.hasClients && _scroll.offset > _kBackToTopOffset;
    if (show != _showTop.value) _showTop.value = show;
  }

  /// وێنەی یەکەم هەواڵەکان پێشوەختە دادەبەزێنێت بۆ ئەوەی کارۆسێلەکە یەکسەر دەربکەوێت.
  Future<void> _precacheImages(Iterable<dynamic> items) async {
    for (final item in items.take(_kPrecacheCount)) {
      if (!mounted) return;
      String img = '';
      try {
        img = ((item as dynamic).primaryImage as String?)?.trim() ?? '';
        if (img.isEmpty || !_precached.add(img)) continue;
        await precacheImage(CachedNetworkImageProvider(img), context);
      } catch (_) {
        // ✅ چاککرا: پێشتر `item` لادەبرا نەک `img` — بۆیە هەرگیز دووبارە هەوڵی نەدەدایەوە
        _precached.remove(img);
      }
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await ref.read(newsProvider.notifier).refresh().catchError((e) {
      debugPrint('⚠️ news refresh error: $e');
    });
  }

  void _openSearch() {
    HapticFeedback.selectionClick();
    final cb = widget.onSearchTap;
    if (cb != null) {
      cb();
    } else {
      Navigator.pushNamed(context, '/search');
    }
  }

  void _openScreen(Widget screen, {String? analyticsName}) {
    if (!mounted) return;
    if (analyticsName != null) AnalyticsService.logScreenView(analyticsName);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openNewsDetails(Map<String, dynamic> news) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NewsDetailsScreen(newsItem: news)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.select<SettingsProvider, String>((s) => s.languageId);
    String t(String key, String fallback) {
      final r = AppTranslations.t(key, lang);
      return r == key ? fallback : r;
    }

    final news = ref.watch(newsProvider.select((s) => s.news));
    final isLoading = ref.watch(newsProvider.select((s) => s.isLoading)) == true;

    ref.listen(newsProvider.select((s) => s.news), (prev, next) {
      final had = prev?.isNotEmpty ?? false;
      if (!had && next.isNotEmpty) _precacheImages(next);
    });

    final iconColor = isDark ? Colors.white : AppColors.primary;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final carouselItems = news.take(_kCarouselCount).map((n) => n.toJson()).toList();
    final List<dynamic> otherNews = news.length > _kCarouselCount
        ? news.skip(_kCarouselCount).take(_kListCount).toList()
        : const <dynamic>[];

    // ✅ چاککرا: پێشتر لە کاتی بارکردندا ئەم بەشە شاردرابووەوە، بۆیە skeleton هەرگیز دەرنەدەکەوت
    // ئەگەر هەموو هەواڵەکان لە سلایدەرەکەدان، بەشی «هەواڵەکانی تر» بەتاڵ پیشان نادرێت
    final showOtherSection = (news.isEmpty && isLoading) || otherNews.isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: _buildBackToTop(t),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(isDark, surfaceColor, iconColor, t),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: news.isNotEmpty
                    ? NewsCarousel(newsList: carouselItems, onTap: _openNewsDetails)
                    : isLoading
                        ? const _CarouselSkeleton()
                        : _NoNewsCard(
                            isDark: isDark,
                            title: t('no_news', 'هیچ هەواڵێک نییە'),
                            subtitle: t('pull_to_refresh', 'بۆ نوێکردنەوە ڕایبکێشە خوارەوە'),
                            retryLabel: t('retry', 'دووبارە'),
                            onRetry: _onRefresh,
                          ),
              ),
            ),

            // 📂 خزمەتگوزارییەکانی تر
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: _SectionHeader(
                      title: t('other_services', 'خزمەتگوزارییەکانی تر'),
                      moreLabel: '',
                      icon: Icons.apps_rounded,
                      color: AppColors.secondary,
                      isDark: isDark,
                    ),
                  ),
                  _buildQuickActions(isDark, t),
                ],
              ),
            ),

            // 📰 هەواڵەکانی تر
            if (showOtherSection) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: _SectionHeader(
                    title: t('more_news', 'هەواڵەکانی تر'),
                    moreLabel: t('see_all', 'بینینی هەموو'),
                    icon: Icons.newspaper_rounded,
                    color: Colors.blue,
                    isDark: isDark,
                    onMoreTap: () => _openScreen(const AllNewsScreen()),
                  ),
                ),
              ),
              _buildNewsListSliver(news, otherNews, isLoading, isDark, t, lang),
            ],

            // بۆشایی بۆ ناڤیگەیشنی خوارەوە (بازنە بەرزەکەشی)
            SliverToBoxAdapter(
              child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark, Color surfaceColor, Color iconColor, String Function(String, String) t) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      scrolledUnderElevation: 3,
      surfaceTintColor: Colors.transparent,
      shadowColor: isDark ? Colors.black.withValues(alpha: 0.35) : AppColors.primary.withValues(alpha: 0.08),
      leading: Builder(
        builder: (ctx) => IconButton(
          tooltip: t('menu', 'مێنیو'),
          icon: Icon(Icons.menu_rounded, color: iconColor),
          onPressed: () {
            HapticFeedback.selectionClick();
            final cb = widget.onMenuTap;
            if (cb != null) {
              cb();
            } else {
              Scaffold.of(ctx).openDrawer();
            }
          },
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: AppColors.newsGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.explore_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              t('app_name', 'ڕێبەری کەلار'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: iconColor),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: t('search', 'گەڕان'),
          icon: Icon(Icons.search_rounded, color: iconColor),
          onPressed: _openSearch,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBackToTop(String Function(String, String) t) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ValueListenableBuilder<bool>(
      valueListenable: _showTop,
      builder: (context, show, _) {
        return IgnorePointer(
          ignoring: !show,
          child: AnimatedScale(
          scale: show ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Padding(
            padding: EdgeInsets.only(bottom: 70 + bottom),
            child: FloatingActionButton.small(
              heroTag: 'home_back_to_top',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: t('back_to_top', 'سەرەوە'),
              onPressed: () {
                HapticFeedback.selectionClick();
                _scroll.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
              },
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(bool isDark, String Function(String, String) t) {
    final actions = <_QuickAction>[
      _QuickAction(
        title: t('neighborhoods', 'گەڕەکان'),
        icon: Icons.location_city_rounded,
        color: AppColors.primary,
        onTap: () => _openScreen(const NeighborhoodsScreen(), analyticsName: 'neighborhoods'),
      ),
      _QuickAction(
        title: t('map', 'نەخشە'),
        icon: Icons.map_rounded,
        color: AppColors.green,
        onTap: () => _openScreen(const MapScreen(), analyticsName: 'map'),
      ),
      _QuickAction(
        title: t('gallery', 'گەلەری'),
        icon: Icons.photo_library_rounded,
        color: AppColors.orange,
        onTap: () => _openScreen(const GalleryScreen(), analyticsName: 'gallery'),
      ),
      _QuickAction(
        title: t('send_complaint', 'ناردنی سکاڵا'),
        icon: Icons.campaign_rounded,
        color: AppColors.toneIndigo,
        onTap: () {
          if (!mounted) return;
          ComplaintInstructionDialog.show(context);
        },
      ),
    ];

    // ✅ هەر چوار دوگمە بەبێ سکڕۆڵ لە هەموو قەبارەیەکی شاشەدا جێدەبنەوە
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _QuickTile(action: actions[i], isDark: isDark)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNewsListSliver(
      List<dynamic> allNews,
      List<dynamic> list,
      bool isLoading,
      bool isDark,
      String Function(String, String) t,
      String lang,
      ) {
    if (allNews.isEmpty && isLoading) {
      return SliverToBoxAdapter(child: _NewsSkeleton(isDark: isDark));
    }

    if (list.isEmpty && !isLoading) {
      return SliverToBoxAdapter(
        child: _EmptyNews(isDark: isDark, label: t('no_more_news', 'هیچ هەواڵێکی تر نییە')),
      );
    }

    final hasMore = allNews.isNotEmpty;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index == list.length) {
            if (!hasMore) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ViewAllButton(
                label: t('see_all_news', 'بینینی هەموو هەواڵەکان'),
                icon: _forwardIcon(context),
                onTap: () => _openScreen(const AllNewsScreen()),
              ),
            );
          }

          final raw = list[index];
          Map<String, dynamic>? map;
          if (raw is Map<String, dynamic>) {
            map = raw;
          } else {
            try {
              map = (raw as dynamic).toJson() as Map<String, dynamic>;
            } catch (e) {
              debugPrint('⚠️ news item conversion error: $e');
            }
          }
          if (map == null) return const SizedBox.shrink();

          final item = map;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RepaintBoundary(
              child: _NewsTile(
                news: item,
                isDark: isDark,
                lang: lang,
                forwardIcon: _forwardIcon(context, small: true),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _openNewsDetails(item);
                },
              ),
            ),
          );
        },
        childCount: list.length + (hasMore ? 1 : 0),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🔧 Free helpers
// ═══════════════════════════════════════════════════════════
/// ئایکۆنەکانی Material خۆیان لە RTL دا وەردەگەڕێن (matchTextDirection)
IconData _forwardIcon(BuildContext context, {bool small = false}) =>
    small ? Icons.arrow_forward_ios_rounded : Icons.arrow_forward_rounded;

class _Fmt {
  const _Fmt._();

  static String digits(String input, [String lang = 'ku']) {
    if (lang == 'en') return input;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < en.length; i++) {
      input = input.replaceAll(en[i], ar[i]);
    }
    return input;
  }

  static String compact(int n, [String lang = 'ku']) {
    String trim(double v) {
      final s = v.toStringAsFixed(1);
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }

    final String out;
    if (n >= 1000000) {
      out = lang == 'en' ? '${trim(n / 1000000)}M' : '${trim(n / 1000000)} ${lang == 'ar' ? 'مليون' : 'ملیۆن'}';
    } else if (n >= 1000) {
      out = lang == 'en' ? '${trim(n / 1000)}K' : '${trim(n / 1000)} ${lang == 'ar' ? 'ألف' : 'هەزار'}';
    } else {
      out = '$n';
    }
    return digits(out, lang);
  }

  static const Map<String, List<String>> _ago = {
    //        now,                  min,      hour,     day,     month,    year,    suffix/prefix
    'ku': ['چەند چرکەیەک پێش ئێستا', 'دەقیقە', 'سەعات', 'ڕۆژ', 'مانگ', 'ساڵ', 'لەمەوبەر'],
    'ar': ['منذ لحظات', 'دقيقة', 'ساعة', 'يوم', 'شهر', 'سنة', 'منذ'],
    'en': ['just now', 'min', 'h', 'd', 'mo', 'y', 'ago'],
  };

  static String timeAgo(String? dateTimeStr, [String lang = 'ku']) {
    final w = _ago[lang] ?? _ago['ku']!;
    if (dateTimeStr == null || dateTimeStr.isEmpty) return w[0];
    try {
      var diff = DateTime.now().difference(DateTime.parse(dateTimeStr));
      if (diff.isNegative) diff = Duration.zero; // کاتی ئامێر لەوانەیە کەمێک پێش بێت

      String fmt(int n, String unit) {
        final v = digits('$n', lang);
        if (lang == 'ar') return '${w[6]} $v $unit';
        if (lang == 'en') return '$v$unit ${w[6]}';
        return '$v $unit ${w[6]}';
      }

      if (diff.inSeconds < 60) return w[0];
      if (diff.inMinutes < 60) return fmt(diff.inMinutes, w[1]);
      if (diff.inHours < 24) return fmt(diff.inHours, w[2]);
      if (diff.inDays < 30) return fmt(diff.inDays, w[3]);
      if (diff.inDays < 365) return fmt(diff.inDays ~/ 30, w[4]);
      return fmt(diff.inDays ~/ 365, w[5]);
    } catch (_) {
      return dateTimeStr.length > 10 ? dateTimeStr.substring(0, 10) : dateTimeStr;
    }
  }

  static String firstImage(dynamic raw) {
    if (raw == null) return '';
    if (raw is List) return raw.isEmpty ? '' : raw.first.toString().trim();
    if (raw is String) {
      var s = raw.trim();
      if (s.isEmpty) return '';
      s = s.replaceAll(RegExp(r'^\[|\]$'), '');
      s = s.replaceAll('"', '').replaceAll("'", '');
      if (s.contains(',')) s = s.split(',').first;
      return s.trim();
    }
    return raw.toString().trim();
  }
}

// ═══════════════════════════════════════════════════════════
// 🧱 Widgets
// ═══════════════════════════════════════════════════════════
class _QuickAction {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.title, required this.icon, required this.color, required this.onTap});
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String moreLabel;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onMoreTap;

  const _SectionHeader({
    required this.title,
    required this.moreLabel,
    required this.icon,
    required this.color,
    required this.isDark,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, 0.18)!, Color.lerp(color, Colors.black, 0.10)!],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(icon, size: 19, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 26,
                height: 3,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        if (onMoreTap != null && moreLabel.isNotEmpty)
          Material(
            color: isDark ? color.withValues(alpha: 0.16) : color.withValues(alpha: 0.08),
            shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.22))),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () {
                HapticFeedback.selectionClick();
                onMoreTap!();
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 5, 5, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr(moreLabel), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
                    const SizedBox(width: 6),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: Icon(_forwardIcon(context, small: true), size: 10, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final _QuickAction action;
  final bool isDark;

  const _QuickTile({required this.action, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final a = action;
    return Semantics(
      button: true,
      label: a.title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.25) : a.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.lightImpact();
              a.onTap();
            },
            excludeFromSemantics: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : a.color.withValues(alpha: 0.10),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(a.color, Colors.white, 0.22)!,
                          Color.lerp(a.color, Colors.black, 0.08)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: a.color.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(a.icon, color: Colors.white, size: 23),
                  ),
                  const SizedBox(height: 10),
                  _TileLabel(
                    text: tr(a.title),
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ناوی دوگمە: وشەیەکی درێژ (Neighborhoods) لە ناوەڕاستدا نابڕدرێت،
/// بەڵکو کەمێک بچووک دەکرێتەوە؛ دەقی چەند وشەیی تا دوو دێڕ دەڕوات.
class _TileLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _TileLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.25, color: color),
      ),
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ViewAllButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            Color.lerp(AppColors.primary, Colors.black, 0.12)!,
            AppColors.primary,
            Color.lerp(AppColors.primary, Colors.white, 0.18)!,
          ],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.newspaper_rounded, color: Colors.white, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 17),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNews extends StatelessWidget {
  final bool isDark;
  final String label;

  const _EmptyNews({required this.isDark, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.backgroundGrey,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.article_outlined, size: 40, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 12),
            Text(
              tr(label),
              style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsTile extends StatelessWidget {
  final Map<String, dynamic> news;
  final bool isDark;
  final String lang;
  final IconData forwardIcon;
  final VoidCallback onTap;

  const _NewsTile({
    required this.news,
    required this.isDark,
    required this.lang,
    required this.forwardIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstImg = _Fmt.firstImage(news['images'] ?? news['img']);
    final title = news['title']?.toString() ?? '';
    final views = (news['views'] as num?)?.toInt() ?? 0;
    final likes = (news['likes'] as num?)?.toInt() ?? 0;
    final timeAgo = _Fmt.timeAgo(news['created_at']?.toString(), lang);

    final store = news['dukan'];
    final storeName = store is Map ? (store['name']?.toString() ?? '') : '';
    final storeLogo = store is Map ? (store['logo']?.toString() ?? store['image']?.toString() ?? '') : '';

    final placeholder = isDark ? AppColors.darkBorder : AppColors.backgroundGrey;
    final subColor = isDark ? Colors.white54 : AppColors.textTertiary;
    final statColor = isDark ? Colors.white54 : AppColors.textSecondary;

    Widget box({Widget? child}) => Container(width: 112, height: 100, color: placeholder, child: child);

    return Semantics(
      button: true,
      label: title,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFEEF2F8),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: firstImg.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: firstImg,
                        width: 112,
                        height: 100,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        fadeInDuration: const Duration(milliseconds: 180),
                        placeholder: (_, __) => box(),
                        errorWidget: (_, __, ___) => box(child: const Icon(Icons.broken_image, color: Colors.grey)),
                      )
                          : box(child: const Icon(Icons.image, color: AppColors.textTertiary)),
                    ),
                    if (storeLogo.isNotEmpty)
                      PositionedDirectional(
                        bottom: 6,
                        end: 6,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: storeLogo,
                              fit: BoxFit.cover,
                              memCacheWidth: 100,
                              errorWidget: (_, __, ___) =>
                              const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 16),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr(title),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            height: 1.45,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            if (storeName.isNotEmpty) ...[
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.storefront_rounded, size: 10, color: AppColors.primary),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          tr(storeName),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                tr(timeAgo),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _Stat(
                              icon: Icons.visibility_rounded,
                              value: _Fmt.compact(views, lang),
                              color: statColor,
                            ),
                            const SizedBox(width: 6),
                            _Stat(
                              icon: Icons.thumb_up_rounded,
                              value: _Fmt.compact(likes, lang),
                              color: AppColors.primary,
                            ),
                            const Spacer(),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(forwardIcon, size: 12, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _Stat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(tr(value), style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
  Tween<double>(begin: 0.45, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _opacity, child: widget.child);
}

class _Bone extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _Bone({this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBorder : AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: _Pulse(child: _Bone(width: double.infinity, height: 180, radius: 22)),
    );
  }
}

class _NewsSkeleton extends StatelessWidget {
  final bool isDark;
  const _NewsSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: List.generate(
            3,
                (_) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  _Bone(width: 112, height: 100, radius: 14),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(width: double.infinity, height: 14, radius: 4),
                        SizedBox(height: 8),
                        _Bone(width: 120, height: 12, radius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _NoNewsCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final String retryLabel;
  final Future<void> Function() onRetry;

  const _NoNewsCard({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.newspaper_rounded, size: 36, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(
            tr(title),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(subtitle),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(tr(retryLabel), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
