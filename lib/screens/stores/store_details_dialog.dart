import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/auto_translate.dart';
import 'store_news_screen.dart';
import '../departments/department_services_screen.dart';
import '../../l10n/tr.dart';
import '../../utils/place_display.dart';

/// 🏪 دیالۆگی وردەکاری شوێن — ULTRA PRO V3
///
/// ✅ چاکسازی:
/// - SnackBar لە پێش Navigator.pop() پیشان دەدرێت (نەک لە پشت barrier)
/// - دوگمەی "سەردانی شوێن" ئێستا شاشەی هەواڵەکانی شوێن دەکاتەوە
/// - phone number cleaning بۆ tel: و whatsapp
class StoreDetailsDialog {
  static void show(BuildContext context, Map<String, dynamic> store) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _StoreDetailsDialogContent(store: store),
    );
  }
}

class _StoreDetailsDialogContent extends StatefulWidget {
  final Map<String, dynamic> store;
  const _StoreDetailsDialogContent({required this.store});

  @override
  State<_StoreDetailsDialogContent> createState() => _StoreDetailsDialogContentState();
}

class _StoreDetailsDialogContentState extends State<_StoreDetailsDialogContent> {
  bool _isFav = false;
  bool _loadingFav = false;
  int _currentImageIndex = 0;
  Map<String, dynamic>? _department;

  @override
  void initState() {
    super.initState();
    _checkIsFav();
    _loadDepartment();
  }

  /// ئەگەر ئەم شوێنە وەک فەرمانگە زیادکرابێت، مامەڵەکانی لێرەوە دەکرێنەوە
  Future<void> _loadDepartment() async {
    final id = widget.store['id'];
    if (id == null) return;
    try {
      final res = await Supabase.instance.client
          .from('departments')
          .select()
          .eq('place_id', '$id')
          .limit(1);
      if (mounted && res.isNotEmpty) {
        setState(() => _department = Map<String, dynamic>.from(res.first));
      }
    } catch (_) {
      // ستوونی place_id هێشتا نییە یان هێڵ نییە — دوگمەکە پیشان نادرێت
    }
  }

  void _openDepartmentServices() {
    final dept = _department;
    if (dept == null) return;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DepartmentServicesScreen(department: dept),
      ),
    );
  }

  Future<void> _checkIsFav() async {
    final user = AuthSessionManager.currentUser;
    if (user == null || user['id'] == null) return;

    try {
      final storeId = int.tryParse(widget.store['id']?.toString() ?? '') ?? widget.store['id'];
      final res = await Supabase.instance.client
          .from('favorite_stores')
          .select()
          .eq('user_id', user['id'])
          .eq('store_id', storeId);
      if (mounted) {
        setState(() => _isFav = (res as List).isNotEmpty);
      }
    } catch (_) {}
  }

  /// ✅ SnackBar لە پێش pop — بۆ ئەوەی لە پشت barrier نەبێت
  void _showSnackBarOnParent(String message, Color color) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    // دوای pop، messenger ی ڕەسەن هێشتا کاردەکات
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          tr(message),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final user = AuthSessionManager.currentUser;
    if (user == null || user['id'] == null) {
      _showSnackBarOnParent('تکایە سەرەتا بچۆ ژوورەوە ⚠', const Color(0xFFD9822B));
      return;
    }

    setState(() => _loadingFav = true);
    final storeId = int.tryParse(widget.store['id']?.toString() ?? '') ?? widget.store['id'];

    try {
      if (_isFav) {
        await Supabase.instance.client
            .from('favorite_stores')
            .delete()
            .eq('user_id', user['id'])
            .eq('store_id', storeId);
        if (mounted) {
          setState(() => _isFav = false);
          _showSnackBarOnParent('لە دڵخوازەکان لادرا 💔', Colors.grey.shade700);
        }
      } else {
        await Supabase.instance.client.from('favorite_stores').insert({
          'user_id': user['id'],
          'store_id': storeId,
        });
        if (mounted) {
          setState(() => _isFav = true);
          _showSnackBarOnParent('بۆ دڵخوازەکان زیادکرا ❤️', const Color(0xFF0F9D7A));
        }
      }
    } catch (e) {
      debugPrint('❌ Favorite error: $e');
      if (mounted) {
        _showSnackBarOnParent('⚠️ هەڵە لە پاشەکەوتکردن', const Color(0xFFDC3545));
      }
    } finally {
      if (mounted) setState(() => _loadingFav = false);
    }
  }

  String _cleanPhone(String phone) {
    var clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = clean.substring(1);
    if (!clean.startsWith('964')) clean = '964$clean';
    return clean;
  }

  void _openStoreNews() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreNewsScreen(store: widget.store),
      ),
    );
  }

  void _share(String name, String address, double? lat, double? lng) {
    final b = StringBuffer('📍 ${tr(name)}\n${tr(address)}');
    if (lat != null && lng != null) {
      b.write('\nhttps://www.google.com/maps/search/?api=1&query=$lat,$lng');
    }
    b.write('\n\n— ${tr('ئەپی ڕێبەری کەلار')}');
    Share.share(b.toString());
  }

  Future<void> _call(String phone) async {
    final clean = _cleanPhone(phone);
    final uri = Uri(scheme: 'tel', path: '0${clean.substring(3)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String phone) async {
    final uri = Uri.parse('https://wa.me/${_cleanPhone(phone)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final lang = context.watch<SettingsProvider>().languageId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String rawName = (store['name'] ?? store['naw'] ?? 'شوێن').toString().trim();
    if (rawName.startsWith('فرۆشگای')) {
      rawName = rawName.replaceFirst('فرۆشگای', '').trim();
    }

    final double? lat = double.tryParse(store['latitude']?.toString() ?? '');
    final double? lng = double.tryParse(store['longitude']?.toString() ?? '');
    final bool hasValidLocation = lat != null && lng != null && lat != 0.0 && lng != 0.0;

    List<String> images = [];
    if (store['images'] is List) {
      images = (store['images'] as List)
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty && s != 'null')
          .toList();
    } else if (store['image'] != null && store['image'].toString().isNotEmpty) {
      images = [store['image'].toString()];
    }

    final String description = (store['description'] ?? '').toString().trim();
    final String phone = (store['phone'] ?? '').toString().trim();

    String address = (store['address'] ?? '').toString().trim();
    if (address.isEmpty || address.contains('کۆئۆردینەت')) {
      address = 'کەلار';
    } else {
      address = PlaceDisplay.address(address);
    }

    final String storeType = (store['type'] ?? 'حکومی').toString().trim();
    final String category = (store['category'] ?? '').toString().trim();
    final bool isGov = storeType == 'حکومی';
    final Color accent = isGov ? AppColors.primary : AppColors.toneRose;

    final bgColor = isDark ? const Color(0xFF1A1A22) : const Color(0xFFF5F7FB);
    final cardColor = isDark ? const Color(0xFF252530) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final lineColor = isDark ? Colors.white10 : const Color(0xFFEEF1F6);

    // ── کردارە خێراکان ──
    final actions = <Widget>[
      if (phone.isNotEmpty)
        _QuickAction(
          icon: Icons.call_rounded,
          label: tr('پەیوەندی'),
          color: AppColors.toneTeal,
          isDark: isDark,
          onTap: () => _call(phone),
        ),
      if (phone.isNotEmpty)
        _QuickAction(
          icon: Icons.chat_rounded,
          label: tr('واتسئاپ'),
          color: const Color(0xFF25D366),
          isDark: isDark,
          onTap: () => _whatsapp(phone),
        ),
      if (hasValidLocation)
        _QuickAction(
          icon: Icons.near_me_rounded,
          label: tr('نەخشە'),
          color: AppColors.primary,
          isDark: isDark,
          onTap: () => _openMap(lat, lng),
        ),
      _QuickAction(
        icon: Icons.ios_share_rounded,
        label: tr('هاوبەشکردن'),
        color: AppColors.toneIndigo,
        isDark: isDark,
        onTap: () =>
            _share(rawName, address, hasValidLocation ? lat : null, hasValidLocation ? lng : null),
      ),
    ];

    // ── ڕیزەکانی زانیاری ──
    final infoRows = <Widget>[
      _InfoRow(
        icon: Icons.location_on_rounded,
        color: AppColors.toneAmber,
        label: tr('ناونیشان'),
        isDark: isDark,
        value: AutoTranslate(
          text: address,
          lang: lang,
          style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w800),
          maxLines: 3,
        ),
      ),
      if (phone.isNotEmpty)
        _InfoRow(
          icon: Icons.phone_rounded,
          color: AppColors.toneTeal,
          label: tr('ژمارەی تەلەفۆن'),
          isDark: isDark,
          onTap: () => _call(phone),
          value: Text(
            phone,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
    ];

    return Directionality(
      textDirection: AppLang.direction,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        backgroundColor: bgColor,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── 🖼️ وێنە ───
                      SizedBox(
                        height: 225,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: images.isNotEmpty
                                  ? PageView.builder(
                                      itemCount: images.length,
                                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                                      itemBuilder: (context, index) => Image.network(
                                        images[index],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _HeroFallback(accent: accent, isGov: isGov),
                                      ),
                                    )
                                  : _HeroFallback(accent: accent, isGov: isGov),
                            ),
                            // سێبەری سەرەوە بۆ دیاربوونی دوگمەکان
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 90,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.30),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 110,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.55),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            PositionedDirectional(
                              top: 14,
                              end: 14,
                              child: _GlassButton(
                                tooltip: tr('داخستن'),
                                onTap: () => Navigator.pop(context),
                                child:
                                    const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                            PositionedDirectional(
                              top: 14,
                              start: 14,
                              child: _GlassButton(
                                tooltip: tr('دڵخواز'),
                                onTap: _loadingFav ? null : _toggleFavorite,
                                child: _loadingFav
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white),
                                      )
                                    : AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 250),
                                        transitionBuilder: (c, a) =>
                                            ScaleTransition(scale: a, child: c),
                                        child: Icon(
                                          _isFav
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          key: ValueKey(_isFav),
                                          color: _isFav ? const Color(0xFFFF4D67) : Colors.white,
                                          size: 22,
                                        ),
                                      ),
                              ),
                            ),
                            // جۆری شوێن
                            PositionedDirectional(
                              bottom: 38,
                              start: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isGov
                                          ? Icons.account_balance_rounded
                                          : Icons.storefront_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    AutoTranslate(
                                      text: storeType,
                                      lang: lang,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (images.length > 1)
                              PositionedDirectional(
                                bottom: 46,
                                end: 18,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(images.length, (i) {
                                    final on = _currentImageIndex == i;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: on ? 18 : 7,
                                      height: 7,
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color:
                                            on ? Colors.white : Colors.white.withValues(alpha: 0.5),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            // لێواری خڕی پەڕەی ناوەڕۆک
                            Positioned(
                              bottom: -1,
                              left: 0,
                              right: 0,
                              height: 26,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius:
                                      const BorderRadius.vertical(top: Radius.circular(26)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── 📄 ناوەڕۆک ───
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AutoTranslate(
                              text: rawName,
                              lang: lang,
                              style: TextStyle(
                                fontSize: 23,
                                height: 1.3,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                            if (category.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: accent.withValues(alpha: 0.18)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.category_rounded, size: 13, color: accent),
                                      const SizedBox(width: 5),
                                      AutoTranslate(
                                        text: category,
                                        lang: lang,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white70 : accent,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),

                            // کردارە خێراکان
                            Row(
                              children: [
                                for (var i = 0; i < actions.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 10),
                                  Expanded(child: actions[i]),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),

                            // زانیاری
                            Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: lineColor),
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < infoRows.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                          height: 1, indent: 66, endIndent: 16, color: lineColor),
                                    infoRows[i],
                                  ],
                                ],
                              ),
                            ),

                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: lineColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: accent,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          tr('وەسف و وردەکاری'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textColor,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    AutoTranslate(
                                      text: description,
                                      lang: lang,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: isDark ? Colors.white70 : const Color(0xFF4A5568),
                                        height: 1.7,
                                      ),
                                      maxLines: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 📋 مامەڵەکانی فەرمانگە — تەنها ئەگەر ئەم شوێنە فەرمانگە بێت
              if (_department != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _openDepartmentServices,
                      icon: const Icon(Icons.fact_check_rounded, size: 20),
                      label: Text(
                        tr('مامەڵە و پێداویستییەکان'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              // ✅ «سەردانی شوێن» — هەمیشە دیارە، شاشەی هەواڵەکانی شوێن دەکاتەوە
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: _PrimaryButton(
                  onTap: _openStoreNews,
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AutoTranslate(
                          text: trf('سەردانی {0}', [rawName]),
                          lang: lang,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// پاشبنەمای وێنە کاتێک شوێنەکە وێنەی نییە
class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.accent, required this.isGov});
  final Color accent;
  final bool isGov;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.black, 0.25)!,
            accent,
            Color.lerp(accent, Colors.white, 0.25)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: _bubble(160, 0.10),
          ),
          Positioned(
            bottom: -50,
            left: -20,
            child: _bubble(140, 0.08),
          ),
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.30), width: 1.5),
              ),
              child: Icon(
                isGov ? Icons.account_balance_rounded : Icons.storefront_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bubble(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

/// دوگمەی شووشەیی لەسەر وێنە
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.child, required this.onTap, required this.tooltip});
  final Widget child;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.black.withValues(alpha: 0.22),
            shape: CircleBorder(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(width: 42, height: 42, child: Center(child: child)),
            ),
          ),
        ),
      ),
    );
  }
}

/// کردارێکی خێرا (پەیوەندی، واتسئاپ، نەخشە، هاوبەشکردن)
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF252530) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFEEF1F6),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : const Color(0xFF4A5568),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ڕیزێکی زانیاری ناو کارتەکە
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.isDark,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final Widget value;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : const Color(0xFF8A94A6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  value,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// دوگمەی سەرەکی بە ڕەنگی تێکەڵ
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: child,
          ),
        ),
      ),
    );
  }
}
