import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/auto_translate.dart';
import 'store_news_screen.dart';
import '../../l10n/tr.dart';

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
  State<_StoreDetailsDialogContent> createState() =>
      _StoreDetailsDialogContentState();
}

class _StoreDetailsDialogContentState extends State<_StoreDetailsDialogContent> {
  bool _isFav = false;
  bool _loadingFav = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkIsFav();
  }

  Future<void> _checkIsFav() async {
    final user = AuthSessionManager.currentUser;
    if (user == null || user['id'] == null) return;

    try {
      final storeId = int.tryParse(widget.store['id']?.toString() ?? '') ??
          widget.store['id'];
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
      _showSnackBarOnParent('تکایە سەرەتا بچۆ ژوورەوە ⚠', Colors.orange);
      return;
    }

    setState(() => _loadingFav = true);
    final storeId =
        int.tryParse(widget.store['id']?.toString() ?? '') ?? widget.store['id'];

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
          _showSnackBarOnParent('بۆ دڵخوازەکان زیادکرا ❤️', const Color(0xFF10B981));
        }
      }
    } catch (e) {
      debugPrint('❌ Favorite error: $e');
      if (mounted) {
        _showSnackBarOnParent('⚠️ هەڵە لە پاشەکەوتکردن', Colors.red);
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

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final lang = context.watch<SettingsProvider>().languageId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String rawName =
    (store['name'] ?? store['naw'] ?? 'شوێن').toString().trim();
    if (rawName.startsWith("فرۆشگای")) {
      rawName = rawName.replaceFirst("فرۆشگای", "").trim();
    }

    final double? lat = double.tryParse(store['latitude']?.toString() ?? '');
    final double? lng = double.tryParse(store['longitude']?.toString() ?? '');
    final bool hasValidLocation =
        lat != null && lng != null && lat != 0.0 && lng != 0.0;

    List<String> images = [];
    if (store['images'] is List) {
      images = (store['images'] as List)
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty && s != 'null')
          .toList();
    } else if (store['image'] != null &&
        store['image'].toString().isNotEmpty) {
      images = [store['image'].toString()];
    }

    final String description = (store['description'] ?? '').toString().trim();
    final String phone = (store['phone'] ?? '').toString().trim();

    String address = (store['address'] ?? '').toString().trim();
    if (address.isEmpty || address.contains('کۆئۆردینەت')) {
      address = 'کەلار';
    }

    final String storeType = (store['type'] ?? 'حکومی').toString().trim();
    final String category = (store['category'] ?? '').toString().trim();
    final bool isGov = storeType == 'حکومی';

    final bgColor = isDark ? const Color(0xFF1A1A22) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF252530) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subTextColor = isDark ? Colors.white70 : Colors.black87;

    return Directionality(
      textDirection: AppLang.direction,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        backgroundColor: bgColor,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      if (images.isNotEmpty)
                        PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return Image.network(
                              images[index],
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: isDark
                                      ? const Color(0xFF252530)
                                      : Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image_rounded,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            size: 70,
                            color: Colors.white,
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                            Colors.black.withValues(alpha: 0.6),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: _loadingFav ? null : _toggleFavorite,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: isDark
                                ? const Color(0xFF252530)
                                : Colors.white,
                            child: _loadingFav
                                ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                                : Icon(
                              _isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: _isFav
                                  ? Colors.redAccent
                                  : (isDark
                                  ? Colors.white54
                                  : Colors.black87),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isGov
                                ? AppColors.primary
                                : const Color(0xFFE91E63),
                            borderRadius: BorderRadius.circular(20),
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
                              const SizedBox(width: 4),
                              AutoTranslate(
                                text: storeType,
                                lang: lang,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (images.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children:
                            List.generate(images.length, (index) {
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == index
                                      ? Colors.white
                                      : Colors.white
                                      .withValues(alpha: 0.5),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: AutoTranslate(
                          text: rawName,
                          lang: lang,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (category.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: AutoTranslate(
                              text: category,
                              lang: lang,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.amber.shade900
                                    .withValues(alpha: 0.2)
                                    : Colors.amber.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: isDark
                                    ? Colors.amber.shade300
                                    : Colors.amber.shade800,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr("ناونیشان"),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  AutoTranslate(
                                    text: address,
                                    lang: lang,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: subTextColor,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (phone.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () async {
                                  final clean = _cleanPhone(phone);
                                  final uri = Uri(
                                    scheme: 'tel',
                                    path: '0${clean.substring(3)}',
                                  );
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.green.shade900
                                        .withValues(alpha: 0.2)
                                        : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.call_rounded,
                                          color: isDark
                                              ? Colors.green.shade300
                                              : Colors.green,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        tr(phone),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.green.shade300
                                              : Colors.green,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: InkWell(
                                onTap: () async {
                                  final clean = _cleanPhone(phone);
                                  final uri = Uri.parse(
                                      "https://wa.me/$clean");
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri,
                                        mode:
                                        LaunchMode.externalApplication);
                                  }
                                },
                                child: Container(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF25D366)
                                        .withValues(alpha: 0.15)
                                        : const Color(0xFFE8F8EF),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                        Icons.chat_bubble_rounded,
                                        color: Color(0xFF25D366),
                                        size: 22),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      if (hasValidLocation)
                        InkWell(
                          onTap: () async {
                            final mapUri = Uri.parse(
                                "https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                            if (await canLaunchUrl(mapUri)) {
                              await launchUrl(mapUri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.blue.shade900
                                        .withValues(alpha: 0.2)
                                        : Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.map_rounded,
                                      color: Colors.blueAccent, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr("شوێنمان لەسەر نەخشە"),
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: subTextColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        tr("کرتە بکە بۆ بینینی GPS 📍"),
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey,
                                    size: 14),
                              ],
                            ),
                          ),
                        ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.description_outlined,
                                      size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr("وەسف و وردەکاری"),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              AutoTranslate(
                                text: description,
                                lang: lang,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: subTextColor,
                                    height: 1.5),
                                maxLines: 10,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // ✅ دوگمەی "سەردانی شوێن" — ئێستا شاشەی هەواڵەکان دەکاتەوە
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 3,
                          ),
                          onPressed: _openStoreNews,
                          icon: const Icon(Icons.storefront_rounded,
                              size: 22),
                          label: AutoTranslate(
                            text: trf("سەردانی {0}", [rawName]),
                            lang: lang,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900),
                            maxLines: 1,
                          ),
                        ),
                      ),
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