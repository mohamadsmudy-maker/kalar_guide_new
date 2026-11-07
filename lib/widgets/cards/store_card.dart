import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../common/auto_translate.dart';
import '../common/optimized_network_image.dart';
import '../../l10n/tr.dart';

/// 🏪 کارتی شوێن — ULTRA PRO MAX v2
///
///  • چاکسازی: ripple ی InkWell پێشتر لەپشت باکگراوندی Container ەوە ون دەبوو
///    (decoration ی بەرز ڕووی داپۆشیبوو) — ئێستا Material خۆی ڕەنگ دەگرێت
///  • تیرەکە بە پێی ئاراستەی زمان (RTL/LTR)، نیشانەی پشتڕاستکراو بە PositionedDirectional
///  • دووری: خوار ١ کم = مەتر، ژمارەی ناوخۆیی، یەکەی بە زمان
///  • چیپەکان بە Wrap (لەگەڵ فۆنتی گەورە ناشکێن)
///  • Semantics بۆ screen reader، haptic لەسەر tap
///  • ئارەزوومەندانە: دوگمەی دڵخواز (`onFavoriteTap` + `isFavorite`)
class StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;

  /// دووری بە کیلۆمەتر
  final double? distance;
  final VoidCallback? onTap;

  /// ئەگەر null بێت دوگمەی دڵخواز پیشان نادرێت
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;

  const StoreCard({
    super.key,
    required this.store,
    this.distance,
    this.onTap,
    this.onFavoriteTap,
    this.isFavorite = false,
  });

  static const Color _govColor = Color(0xFF10B981);
  static const Color _privateColor = Color(0xFFE91E63);
  static const Color _verifiedColor = Color(0xFF3B82F6);

  static const Map<String, Map<String, String>> _tr = {
    'store': {'ku': 'شوێن', 'ar': 'موقع', 'en': 'Place'},
    'km': {'ku': 'کم', 'ar': 'كم', 'en': 'km'},
    'm': {'ku': 'م', 'ar': 'م', 'en': 'm'},
    'verified': {'ku': 'پشتڕاستکراوە', 'ar': 'موثق', 'en': 'Verified'},
    'fav_add': {'ku': 'زیادکردن بۆ دڵخواز', 'ar': 'إضافة للمفضلة', 'en': 'Add to favorites'},
    'fav_remove': {'ku': 'لابردن لە دڵخواز', 'ar': 'إزالة من المفضلة', 'en': 'Remove from favorites'},
  };

  static String _digits(String s, String lang) {
    if (lang == 'en') return s;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < en.length; i++) {
      s = s.replaceAll(en[i], ar[i]);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.select<SettingsProvider, String>((s) => s.languageId);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    String t(String k) => _tr[k]?[lang] ?? _tr[k]?['en'] ?? k;

    final rawName = store['name']?.toString().trim() ?? '';
    final name = rawName.isEmpty ? t('store') : rawName;
    final rawAddress = store['address']?.toString().trim() ?? '';
    final address = rawAddress.isEmpty ? 'کەلار' : rawAddress;
    final category = store['category']?.toString().trim() ?? '';
    final image = store['image']?.toString().trim() ?? '';
    final type = store['type']?.toString().trim() ?? '';
    final isGov = type == 'حکومی' || type.toLowerCase() == 'government';
    final isVerified = store['is_verified'] == true;

    final accent = isGov ? _govColor : _privateColor;
    final cardColor = isDark ? const Color(0xFF1A1A22) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade100;

    final distanceText = distance == null
        ? null
        : distance! < 1
        ? '${_digits('${(distance! * 1000).round()}', lang)} ${t('m')}'
        : '${_digits(distance!.toStringAsFixed(1), lang)} ${t('km')}';

    final semanticsLabel = [
      name,
      address,
      if (category.isNotEmpty) category,
      if (distanceText != null) distanceText,
      if (isVerified) t('verified'),
    ].join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        button: onTap != null,
        label: semanticsLabel,
        excludeSemantics: true,
        onTap: onTap,
        child: Container(
          // سێبەر و دیواری دەرەوە — Material ی ناوەوە ڕەنگ و ripple دەگرێت
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Material(
            color: cardColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: borderColor, width: 1.5),
            ),
            child: InkWell(
              onTap: onTap == null
                  ? null
                  : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // 🖼️ وێنە
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: image.isNotEmpty
                                ? OptimizedNetworkImage(
                              imageUrl: image,
                              width: 78,
                              height: 78,
                              fit: BoxFit.cover,
                            )
                                : Container(
                              color: accent.withValues(alpha: 0.1),
                              child: Icon(
                                isGov
                                    ? Icons.account_balance_rounded
                                    : Icons.storefront_rounded,
                                color: accent,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        if (isVerified)
                          PositionedDirectional(
                            bottom: -2,
                            end: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _verifiedColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cardColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // 📝 زانیاری
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AutoTranslate(
                            text: name,
                            lang: lang,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color:
                              isDark ? Colors.white : AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: accent.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: AutoTranslate(
                                  text: address,
                                  lang: lang,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          if (category.isNotEmpty || distanceText != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (category.isNotEmpty)
                                  _Chip(
                                    color: accent,
                                    child: AutoTranslate(
                                      text: category,
                                      lang: lang,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                if (distanceText != null)
                                  _Chip(
                                    color: Colors.green,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.near_me_rounded,
                                            size: 10, color: Colors.green),
                                        const SizedBox(width: 3),
                                        Text(
                                          tr(distanceText),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // دڵخواز + تیر
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onFavoriteTap != null) ...[
                          Tooltip(
                            message:
                            isFavorite ? t('fav_remove') : t('fav_add'),
                            child: InkResponse(
                              radius: 20,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                onFavoriteTap!();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (c, a) =>
                                      ScaleTransition(scale: a, child: c),
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    key: ValueKey(isFavorite),
                                    size: 20,
                                    color: isFavorite
                                        ? const Color(0xFFEC4899)
                                        : (isDark
                                        ? Colors.white38
                                        : Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade50,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Icon(
                            rtl
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                            color:
                            isDark ? Colors.white54 : Colors.grey.shade500,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final Color color;
  final Widget child;

  const _Chip({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}