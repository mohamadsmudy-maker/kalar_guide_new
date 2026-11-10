import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../news/news_details.dart';
import '../admin/admin_news.dart';
import '../../l10n/tr.dart';
import '../../utils/place_display.dart';
import '../currency/currency_strings.dart';

class StoreNewsScreen extends StatefulWidget {
  final Map<String, dynamic> store;
  const StoreNewsScreen({super.key, required this.store});

  @override
  State<StoreNewsScreen> createState() => _StoreNewsScreenState();
}

class _StoreNewsScreenState extends State<StoreNewsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _storeNews = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStoreNews();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStoreNews() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('news')
          .select()
          .eq('store_id', widget.store['id'])
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _storeNews = List<Map<String, dynamic>>.from(res as List);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _extractFirstImage(dynamic rawImages) {
    if (rawImages == null) return '';
    if (rawImages is List) {
      if (rawImages.isEmpty) return '';
      return rawImages.first.toString().trim();
    }
    if (rawImages is String) {
      var s = rawImages.trim();
      if (s.isEmpty) return '';
      s = s.replaceAll(RegExp(r'^\[|\]$'), '');
      s = s.replaceAll('"', '').replaceAll("'", '');
      if (s.contains(',')) s = s.split(',').first;
      return s.trim();
    }
    return rawImages.toString().trim();
  }

  /// جۆرەکانی بڵاوکراوە: ئایکۆن و ڕەنگ (هەمان شێوەی فۆرمی هەواڵ)
  static (IconData, Color) _typeStyle(String t) => switch (t) {
        'ئاگاداری' => (Icons.campaign_rounded, AppColors.toneAmber),
        'هۆشداری' => (Icons.warning_amber_rounded, AppColors.toneRed),
        'ڕووداو' => (Icons.event_rounded, AppColors.toneIndigo),
        'خزمەتگوزاری' => (Icons.volunteer_activism_rounded, AppColors.toneTeal),
        _ => (Icons.newspaper_rounded, AppColors.toneBlue),
      };

  String _type = 'هەموو';

  String _ago(Map<String, dynamic> n) =>
      CurrencyStrings.timeAgo(DateTime.tryParse('${n['created_at'] ?? ''}'), AppLang.code);

  int _num(Object? v) => (v as num?)?.toInt() ?? 0;

  Future<void> _openNews(Map<String, dynamic> news) async {
    HapticFeedback.selectionClick();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailsScreen(newsItem: news)));
    if (mounted) _fetchStoreNews();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String rawName = (store['name'] ?? 'شوێن').toString().trim();
    if (rawName.startsWith('فرۆشگای')) {
      rawName = rawName.replaceFirst('فرۆشگای', '').trim();
    } else if (rawName.startsWith('فرۆشگا')) {
      rawName = rawName.replaceFirst('فرۆشگا', '').trim();
    }

    final user = AuthSessionManager.currentUser;
    final canPost = AuthSessionManager.isAdmin ||
        (user != null && user['role'] == 'vendor' && user['store_id']?.toString() == store['id']?.toString());

    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF4F6FA);
    final card = isDark ? AppColors.darkCard : Colors.white;
    final text = isDark ? Colors.white : AppColors.textPrimary;
    final sub = isDark ? Colors.white54 : AppColors.textSecondary;

    final types = <String>{for (final n in _storeNews) '${n['news_type'] ?? 'هەواڵ'}'};
    final q = _searchQuery.toLowerCase();
    final filtered = _storeNews.where((n) {
      if (_type != 'هەموو' && '${n['news_type'] ?? 'هەواڵ'}' != _type) return false;
      if (q.isEmpty) return true;
      return '${n['title'] ?? ''}'.toLowerCase().contains(q) || '${n['description'] ?? ''}'.toLowerCase().contains(q);
    }).toList();
    final views = _storeNews.fold<int>(0, (s, n) => s + _num(n['views']));
    final logo = '${store['logo'] ?? ''}'.startsWith('http') ? '${store['logo']}' : '${store['image'] ?? ''}';

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bg,
        floatingActionButton: canPost
            ? FloatingActionButton.extended(
                heroTag: 'store_news_add',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddNewsScreen(forcedStoreId: store['id'].toString())),
                  );
                  if (mounted) _fetchStoreNews();
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(tr('هەواڵی نوێ'), style: const TextStyle(fontWeight: FontWeight.w900)),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: _fetchStoreNews,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ─── سەرپەڕە ───
              SliverAppBar(
                expandedHeight: 210,
                pinned: true,
                stretch: true,
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if ('${store['image'] ?? ''}'.startsWith('http'))
                        OptimizedNetworkImage(imageUrl: '${store['image']}', fit: BoxFit.cover)
                      else
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF111827), Color(0xFF1E3A5F)],
                            ),
                          ),
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xE6000000), Color(0x33000000), Color(0x00000000)],
                            stops: [0, 0.55, 1],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: 16,
                        start: 16,
                        end: 16,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: logo.startsWith('http')
                                  ? OptimizedNetworkImage(imageUrl: logo, fit: BoxFit.cover)
                                  : const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 30),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          tr(rawName),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 18),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _heroChip(Icons.location_on_rounded, tr(PlaceDisplay.address(store['address']))),
                                      if (!_isLoading)
                                        _heroChip(Icons.article_rounded,
                                            trf('{0} هەواڵ', [PlaceDisplay.digits(_storeNews.length)])),
                                      if (!_isLoading && views > 0)
                                        _heroChip(Icons.visibility_rounded,
                                            trf('{0} بینین', [PlaceDisplay.digits(views)])),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── گەڕان + فلتەر ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: TextStyle(color: text),
                        decoration: InputDecoration(
                          hintText: tr('گەڕان بەدوای هەواڵەکاندا...'),
                          hintStyle: TextStyle(fontSize: 13, color: sub),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                          filled: true,
                          fillColor: card,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(tr('هەواڵ و ئاگادارییەکان'),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: text)),
                          ),
                          if (!_isLoading)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(PlaceDisplay.digits(filtered.length),
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
                            ),
                        ],
                      ),
                      if (types.length > 1) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final t in ['هەموو', ...types])
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 8),
                                  child: ChoiceChip(
                                    selected: _type == t,
                                    showCheckmark: false,
                                    onSelected: (_) => setState(() => _type = t),
                                    avatar: t == 'هەموو'
                                        ? null
                                        : Icon(_typeStyle(t).$1,
                                            size: 16, color: _type == t ? Colors.white : _typeStyle(t).$2),
                                    label: Text(tr(t)),
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _type == t ? Colors.white : (t == 'هەموو' ? text : _typeStyle(t).$2),
                                    ),
                                    selectedColor: t == 'هەموو' ? AppColors.primary : _typeStyle(t).$2,
                                    backgroundColor: card,
                                    side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE6EAF0)),
                                    shape: const StadiumBorder(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ─── لیست ───
              if (_isLoading)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.article_outlined, size: 44, color: AppColors.primary),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          tr(_storeNews.isEmpty ? 'هێشتا هیچ هەواڵێک بڵاو نەکراوەتەوە' : 'هیچ ئەنجامێک نییە'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        if (_storeNews.isEmpty && canPost) ...[
                          const SizedBox(height: 6),
                          Text(tr('یەکەم هەواڵ بڵاو بکەرەوە'), style: TextStyle(color: sub)),
                        ],
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => i == 0 && _searchQuery.isEmpty
                        ? _featuredCard(filtered[i], card, text, sub)
                        : _newsCard(filtered[i], card, text, sub),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _typePill(String t, {bool onImage = false}) {
    final (icon, color) = _typeStyle(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onImage ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onImage ? Colors.white : color),
          const SizedBox(width: 4),
          Text(tr(t),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: onImage ? Colors.white : color)),
        ],
      ),
    );
  }

  Widget _meta(Map<String, dynamic> n, Color sub) => Row(
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: sub),
          const SizedBox(width: 3),
          Flexible(
            child: Text(_ago(n),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: sub)),
          ),
          const SizedBox(width: 10),
          Icon(Icons.visibility_rounded, size: 13, color: sub),
          const SizedBox(width: 3),
          Text(PlaceDisplay.digits(_num(n['views'])), style: TextStyle(fontSize: 11, color: sub)),
          const SizedBox(width: 10),
          Icon(Icons.thumb_up_rounded, size: 13, color: sub),
          const SizedBox(width: 3),
          Text(PlaceDisplay.digits(_num(n['likes'])), style: TextStyle(fontSize: 11, color: sub)),
        ],
      );

  /// نوێترین هەواڵ: کارتی گەورە بە وێنە
  Widget _featuredCard(Map<String, dynamic> n, Color card, Color text, Color sub) {
    final img = _extractFirstImage(n['images'] ?? n['img']);
    final t = '${n['news_type'] ?? 'هەواڵ'}';
    final (icon, color) = _typeStyle(t);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: () => _openNews(n),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (img.startsWith('http'))
                      OptimizedNetworkImage(imageUrl: img, fit: BoxFit.cover)
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color.lerp(color, Colors.black, 0.2)!, color],
                          ),
                        ),
                        child: Icon(icon, size: 56, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    PositionedDirectional(top: 12, start: 12, child: _typePill(t, onImage: true)),
                    PositionedDirectional(
                      top: 12,
                      end: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tr('نوێترین'),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(n['title']?.toString() ?? ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: text, height: 1.35),
                    ),
                    if ('${n['description'] ?? ''}'.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        tr(n['description'].toString()),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: sub, height: 1.6),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _meta(n, sub),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _newsCard(Map<String, dynamic> n, Color card, Color text, Color sub) {
    final img = _extractFirstImage(n['images'] ?? n['img']);
    final t = '${n['news_type'] ?? 'هەواڵ'}';
    final (icon, color) = _typeStyle(t);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openNews(n),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: img.startsWith('http')
                        ? OptimizedNetworkImage(imageUrl: img, fit: BoxFit.cover)
                        : ColoredBox(
                            color: color.withValues(alpha: 0.12),
                            child: Icon(icon, color: color, size: 32),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _typePill(t),
                      const SizedBox(height: 6),
                      Text(
                        tr(n['title']?.toString() ?? ''),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: text, height: 1.35),
                      ),
                      const SizedBox(height: 6),
                      _meta(n, sub),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
