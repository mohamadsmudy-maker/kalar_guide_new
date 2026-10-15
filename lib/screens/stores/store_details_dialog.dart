import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../services/store_service_service.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/common/optimized_network_image.dart';
import 'store_news_screen.dart';
import 'store_services_screen.dart';

/// 🏪 دیالۆگی وردەکاری شوێن
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

class _StoreDetailsDialogContentState
    extends State<_StoreDetailsDialogContent> {
  bool _isFav = false;
  bool _loadingFav = false;
  int _servicesCount = 0;
  bool _loadingServices = true;

  @override
  void initState() {
    super.initState();
    _checkIsFav();
    _loadServicesCount();
  }

  Future<void> _loadServicesCount() async {
    final storeId = int.tryParse(widget.store['id'].toString()) ?? 0;
    final count = await StoreServiceService.getCount(storeId);
    if (mounted) {
      setState(() {
        _servicesCount = count;
        _loadingServices = false;
      });
    }
  }

  Future<void> _checkIsFav() async {
    final user = AuthSessionManager.currentUser;
    if (user == null) return;

    try {
      final res = await Supabase.instance.client
          .from('favorite_stores')
          .select()
          .eq('user_id', user['id'])
          .eq('store_id', widget.store['id']);
      if (mounted) {
        setState(() => _isFav = (res as List).isNotEmpty);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final user = AuthSessionManager.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە سەرەتا بچۆ ژوورەوە ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loadingFav = true);
    try {
      if (_isFav) {
        await Supabase.instance.client
            .from('favorite_stores')
            .delete()
            .eq('user_id', user['id'])
            .eq('store_id', widget.store['id']);
        if (mounted) {
          setState(() => _isFav = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("لە دڵخوازەکان لادرا 💔"),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        await Supabase.instance.client.from('favorite_stores').insert({
          'user_id': user['id'],
          'store_id': widget.store['id'],
        });
        if (mounted) {
          setState(() => _isFav = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("بۆ دڵخوازەکان زیادکرا ❤"),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingFav = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final lang = context.watch<SettingsProvider>().languageId;

    String rawName =
    (store['name'] ?? store['naw'] ?? 'شوێن').toString().trim();
    if (rawName.startsWith("فرۆشگای")) {
      rawName = rawName.replaceFirst("فرۆشگای", "").trim();
    }

    final double? lat =
    double.tryParse(store['latitude']?.toString() ?? '');
    final double? lng =
    double.tryParse(store['longitude']?.toString() ?? '');
    final bool hasValidLocation =
        lat != null && lng != null && lat != 0.0 && lng != 0.0;

    final String imageUrl = (store['image'] ?? '').toString().trim();
    final String description =
    (store['description'] ?? '').toString().trim();
    final String phone = (store['phone'] ?? '').toString().trim();
    final String address =
    (store['address'] ?? 'کەلار').toString().trim();
    final String storeType =
    (store['type'] ?? 'حکومی').toString().trim();
    final String category = (store['category'] ?? '').toString().trim();
    final bool isGov = storeType == 'حکومی';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Container(
          color: const Color(0xFFF8F9FA),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ═══════════════════════════════════════════
                // 🖼️ وێنە
                // ═══════════════════════════════════════════
                Hero(
                  tag: 'store_image_${store['id']}',
                  child: Stack(
                    children: [
                      imageUrl.isNotEmpty
                          ? OptimizedNetworkImage(
                        imageUrl: imageUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary
                                  .withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
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
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
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
                            backgroundColor: Colors.white,
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
                                  : Colors.black87,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      // 🏷️ جۆری شوێن
                      Positioned(
                        bottom: 12,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                    ],
                  ),
                ),

                // ═══════════════════════════════════════════
                // 📝 زانیارییەکان
                // ═══════════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ ناوی شوێن
                      Center(
                        child: AutoTranslate(
                          text: rawName,
                          lang: lang,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: 0.5,
                          ),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // ✅ کەرت
                      if (category.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: AutoTranslate(
                              text: category,
                              lang: lang,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 📍 ناونیشان
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color:
                              Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: Colors.amber.shade800,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "ناونیشان",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  AutoTranslate(
                                    text: address,
                                    lang: lang,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
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

                      // 📋 دوگمەی مامەڵەکان و تێچووی
                      if (!_loadingServices && _servicesCount > 0) ...[
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoreServicesScreen(
                                  storeId: int.tryParse(
                                    store['id'].toString(),
                                  ) ??
                                      0,
                                  storeName: rawName,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF8B5CF6),
                                  Color(0xFFEC4899),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.2),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.description_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '📋 مامەڵەکان و تێچووی',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'پێداویستی و نرخی مامەڵەکان',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$_servicesCount',
                                    style: const TextStyle(
                                      color: Color(0xFF8B5CF6),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 📱 مۆبایل و واتسئاپ
                      if (phone.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () async {
                                  final Uri uri =
                                  Uri(scheme: 'tel', path: phone);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius:
                                    BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.green
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.call_rounded,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        phone,
                                        style: const TextStyle(
                                          color: Colors.green,
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
                                  String cleanPhone = phone;
                                  if (cleanPhone.startsWith('0')) {
                                    cleanPhone =
                                        cleanPhone.substring(1);
                                  }
                                  if (!cleanPhone.startsWith('964')) {
                                    cleanPhone = '964$cleanPhone';
                                  }
                                  final Uri uri = Uri.parse(
                                    "https://wa.me/$cleanPhone",
                                  );
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F8EF),
                                    borderRadius:
                                    BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF25D366)
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.chat_bubble_rounded,
                                      color: Color(0xFF25D366),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),

                      // 🗺️ لوکەیشن
                      if (hasValidLocation)
                        InkWell(
                          onTap: () async {
                            final Uri mapUri = Uri.parse(
                              "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
                            );
                            if (await canLaunchUrl(mapUri)) {
                              await launchUrl(
                                mapUri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.map_rounded,
                                    color: Colors.blueAccent,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "شوێنمان لەسەر نەخشە",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "کرتە بکە بۆ بینینی GPS 📍",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.grey,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ✅ وەسف
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "وەسف و وردەکاری",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              AutoTranslate(
                                text: description,
                                lang: lang,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                                maxLines: 10,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // 🔵 دوگمەی سەردانی شوێن
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                            shadowColor:
                            AppColors.primary.withValues(alpha: 0.4),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    StoreNewsScreen(store: store),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.storefront_rounded,
                            size: 22,
                          ),
                          label: AutoTranslate(
                            text: "سەردانی $rawName",
                            lang: lang,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
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