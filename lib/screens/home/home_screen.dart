import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../config/translations.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../widgets/carousels/news_carousel.dart';
import '../complaints/complaint_instruction_dialog.dart';
import '../news/news_details.dart';

/// 🏠 شاشەی سەرەکی - PRO EDITION
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          const SizedBox(height: 12),
          _buildImportantNewsSection(isDark, lang),
          const SizedBox(height: 20),
          _buildComplaintButton(lang),
          const SizedBox(height: 22),
          _buildSectionHeader(
            title: "بەشە سەرەکییەکان",
            icon: Icons.grid_view_rounded,
            iconColor: AppColors.primary,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildCategoriesSection(isDark, lang),
          const SizedBox(height: 22),
          _buildSectionHeader(
            title: "هەواڵەکانی تر 📰",
            icon: Icons.newspaper_rounded,
            iconColor: Colors.blue,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildNewsList(isDark, lang),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Section Header
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconColor.withValues(alpha: 0.15),
                  iconColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📢 Complaint Button
  // ═══════════════════════════════════════════════════════════
  Widget _buildComplaintButton(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => ComplaintInstructionDialog.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: AppColors.complaintGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ناردنی سکاڵای هاوڵاتی 📢",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "کێشە و گرفتەکانی شارت لێرە بنێرە",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📦 Categories Section
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoriesSection(bool isDark, String lang) {
    return SizedBox(
      height: 125,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCategories(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          Map<String, Map<String, dynamic>> uniqueMap = {};
          for (var cat in snapshot.data!) {
            uniqueMap[cat['name']] = cat;
          }
          var mainCats = uniqueMap.values.toList();

          if (mainCats.isEmpty) {
            return Center(
              child: Text(
                "هیچ بەشێک نییە",
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
              ),
            );
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: mainCats.length,
            itemBuilder: (context, index) {
              var cat = mainCats[index];
              final String catName = cat['name'] ?? '';
              final String? catImage = cat['image'];
              final Color catColor = _getCategoryColor(catName);
              final String displayName = _translateCategory(catName, lang);

              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/category',
                      arguments: catName,
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              catColor.withValues(
                                alpha: isDark ? 0.25 : 0.15,
                              ),
                              catColor.withValues(
                                alpha: isDark ? 0.10 : 0.05,
                              ),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: catColor.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: catImage != null && catImage.isNotEmpty
                              ? OptimizedNetworkImage(
                            imageUrl: catImage,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          )
                              : Icon(
                            _getCategoryIcon(catName),
                            color: catColor,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color:
                            isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📰 News List
  // ═══════════════════════════════════════════════════════════
  Widget _buildNewsList(bool isDark, String lang) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchNews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A1A22)
                          : AppColors.backgroundGrey,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.article_outlined,
                      size: 40,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "هیچ هەواڵێک نییە 📰",
                    style: TextStyle(
                      color: isDark
                          ? Colors.white54
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        var newsList = snapshot.data!;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: newsList.length,
          itemBuilder: (context, index) {
            return _buildNewsListItem(newsList[index], isDark, lang);
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 Data Fetching
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _fetchNews() async {
    try {
      final res = await Supabase.instance.client
          .from('news')
          .select('*, dukan(name, logo, image)')
          .order('id', ascending: false)
          .limit(10);

      final List<dynamic> rawList = res as List;
      return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCategories() async {
    try {
      final res =
      await Supabase.instance.client.from('main_categories').select();

      final List<dynamic> rawList = res as List;
      return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📰 Important News Section
  // ═══════════════════════════════════════════════════════════
  Widget _buildImportantNewsSection(bool isDark, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: AppColors.newsGradient,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "هەواڵ و ئاگاداری گرنگ 📢",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchNews(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 340,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                    isDark ? const Color(0xFF2A2A35) : AppColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    "هیچ هەواڵێکی گرنگ نییە 📰",
                    style: TextStyle(
                      color: isDark
                          ? Colors.white54
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }

            var newsList = snapshot.data!.take(5).toList();

            return NewsCarousel(
              newsList: newsList,
              onTap: (news) {
                Supabase.instance.client
                    .from('news')
                    .update({'views': (news['views'] ?? 0) + 1})
                    .eq('id', news['id'])
                    .then((_) {});
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewsDetailsScreen(newsItem: news),
                  ),
                ).then((_) => setState(() {}));
              },
            );
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📰 News List Item
  // ═══════════════════════════════════════════════════════════
  Widget _buildNewsListItem(
      Map<String, dynamic> news, bool isDark, String lang) {
    String firstImg = _extractFirstImage(news['images'] ?? news['img']);
    String timeAgo = _getTimeAgo(news['created_at'], lang);

    final store = news['dukan'];
    final storeName = store?['name']?.toString() ?? '';
    final storeLogo = store?['logo']?.toString() ??
        store?['image']?.toString() ??
        '';

    return GestureDetector(
      onTap: () {
        Supabase.instance.client
            .from('news')
            .update({'views': (news['views'] ?? 0) + 1})
            .eq('id', news['id'])
            .then((_) {});

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailsScreen(newsItem: news),
          ),
        ).then((_) => setState(() {}));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: firstImg.isNotEmpty
                      ? OptimizedNetworkImage(
                    imageUrl: firstImg,
                    width: 100,
                    height: 90,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    width: 100,
                    height: 90,
                    color: isDark
                        ? const Color(0xFF2A2A35)
                        : AppColors.backgroundGrey,
                    child: const Icon(
                      Icons.image,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                if (storeLogo.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: storeLogo,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      news['title'] ?? news['description'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (storeName.isNotEmpty) ...[
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.storefront_rounded,
                                    size: 10,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      storeName,
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
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildStatItem(
                          icon: Icons.visibility_rounded,
                          value: "${news['views'] ?? 0}",
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        _buildStatItem(
                          icon: Icons.thumb_up_rounded,
                          value: "${news['likes'] ?? 0}",
                          color: AppColors.primary,
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
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
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

  String _getTimeAgo(String? dateTimeStr, String lang) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return lang == 'ku' ? 'کەمێک پێش ئێستا' : 'Just now';
    }
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      Duration diff = DateTime.now().difference(dateTime);

      if (diff.inSeconds < 60) return 'چەند چرکەیەک پێش ئێستا';
      if (diff.inMinutes < 60) return '${diff.inMinutes} دەقیقە لەمەوبەر';
      if (diff.inHours < 24) return '${diff.inHours} سەعات لەمەوبەر';
      if (diff.inDays < 30) return '${diff.inDays} ڕۆژ لەمەوبەر';
      return '${(diff.inDays / 30).floor()} مانگ لەمەوبەر';
    } catch (_) {
      return dateTimeStr.length > 10
          ? dateTimeStr.substring(0, 10)
          : dateTimeStr;
    }
  }

  String _translateCategory(String name, String lang) {
    final map = {
      'تەندروستی': 'cat_health',
      'پەروەردە': 'cat_education',
      'خوێندنی باڵا': 'cat_higher_ed',
      'بەڕێوەبەرایەتی': 'cat_government',
      'خواردن': 'cat_food',
      'بازاڕگەری': 'cat_shopping',
    };
    final key = map[name];
    if (key == null) return name;
    final translated = AppTranslations.t(key, lang);
    return translated == key ? name : translated;
  }

  IconData _getCategoryIcon(String name) {
    final n = name.trim();
    if (n.contains('تەندروستی') || n.contains('نەخۆشخانە')) {
      return Icons.local_hospital_rounded;
    }
    if (n.contains('پەروەردە') || n.contains('قوتابخانە')) {
      return Icons.school_rounded;
    }
    if (n.contains('بەڕێوەبەرایەتی') || n.contains('شارەوانی')) {
      return Icons.account_balance_rounded;
    }
    if (n.contains('خوێندنی باڵا') || n.contains('زانکۆ')) {
      return Icons.school_rounded;
    }
    if (n.contains('خواردن') || n.contains('شیرینی')) {
      return Icons.restaurant_rounded;
    }
    if (n.contains('بازاڕ') || n.contains('شوێن')) {
      return Icons.shopping_bag_rounded;
    }
    return Icons.category_rounded;
  }

  Color _getCategoryColor(String name) {
    final n = name.trim();
    if (n.contains('تەندروستی') || n.contains('نەخۆشخانە')) {
      return AppColors.catHealth;
    }
    if (n.contains('پەروەردە') || n.contains('قوتابخانە')) {
      return AppColors.catEducation;
    }
    if (n.contains('بەڕێوەبەرایەتی') || n.contains('شارەوانی')) {
      return AppColors.catGovernment;
    }
    if (n.contains('خوێندنی باڵا') || n.contains('زانکۆ')) {
      return AppColors.catHigherEd;
    }
    if (n.contains('خواردن') || n.contains('شیرینی')) {
      return AppColors.catFood;
    }
    if (n.contains('بازاڕ') || n.contains('شوێن')) {
      return AppColors.catShopping;
    }
    return AppColors.primary;
  }
}