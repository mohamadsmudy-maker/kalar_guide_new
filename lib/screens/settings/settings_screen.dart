import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../config/theme_provider.dart';

/// ⚙️ شاشەی ڕێکخستن — ULTRA PRO V3
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _hasChanges = false;

  // ✨ Animations
  late AnimationController _headerController;
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _headerAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _headerController.forward();
    _entryController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF5F6FA),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isDark),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ⭐ Quick Info
                    _buildQuickInfo(isDark, settings, itemIndex: 0),

                    const SizedBox(height: 20),

                    // ⭐ Search
                    _buildSearchBar(isDark),

                    const SizedBox(height: 20),

                    // ⭐ Language
                    _buildSectionTitle(
                      '🌍 زمان',
                      isDark,
                      itemIndex: 1,
                    ),
                    const SizedBox(height: 12),
                    ...SettingsProvider.availableLanguages.map((lang) {
                      return _buildLanguageOption(
                        languageId: lang['id']!,
                        languageName: lang['name']!,
                        nativeName: lang['native']!,
                        flag: lang['flag']!,
                        isSelected: settings.languageId == lang['id'],
                        isDark: isDark,
                        onTap: () {
                          settings.setLanguage(lang['id']!);
                          _markChanged();
                        },
                        itemIndex: 2,
                      );
                    }),

                    const SizedBox(height: 20),

                    // ⭐ Font
                    _buildSectionTitle(
                      '🔤 جۆری فۆنت',
                      isDark,
                      itemIndex: 3,
                    ),
                    const SizedBox(height: 12),
                    _buildFontDropdown(isDark, settings, itemIndex: 4),

                    const SizedBox(height: 20),

                    // ⭐ Font Size
                    _buildSectionTitle(
                      '📏 قەبارەی فۆنت',
                      isDark,
                      itemIndex: 5,
                    ),
                    const SizedBox(height: 12),
                    ...SettingsProvider.availableFontSizes.map((size) {
                      return _buildFontSizeOption(
                        sizeId: size['id']!,
                        sizeName: size['name']!,
                        scale: (size['scale'] as num).toDouble(),
                        isSelected: settings.fontSizeId == size['id'],
                        isDark: isDark,
                        onTap: () {
                          settings.setFontSize(size['id']!);
                          _markChanged();
                        },
                        itemIndex: 6,
                      );
                    }),

                    const SizedBox(height: 20),

                    // ⭐ Preview
                    _buildSectionTitle(
                      '👁️ پێشبینین',
                      isDark,
                      itemIndex: 7,
                    ),
                    const SizedBox(height: 12),
                    _buildPreviewCard(isDark, settings, itemIndex: 8),

                    const SizedBox(height: 20),

                    // ⭐ Theme
                    _buildSectionTitle(
                      '🌙 ڕەنگی ئەپ',
                      isDark,
                      itemIndex: 9,
                    ),
                    const SizedBox(height: 12),
                    _buildThemeOption(
                      context,
                      mode: ThemeMode.light,
                      icon: Icons.light_mode_rounded,
                      title: 'ڕووناک',
                      subtitle: 'Light',
                      color: Colors.orange,
                      isDark: isDark,
                      itemIndex: 10,
                    ),
                    _buildThemeOption(
                      context,
                      mode: ThemeMode.dark,
                      icon: Icons.dark_mode_rounded,
                      title: 'تاریک',
                      subtitle: 'Dark',
                      color: Colors.purple,
                      isDark: isDark,
                      itemIndex: 11,
                    ),
                    _buildThemeOption(
                      context,
                      mode: ThemeMode.system,
                      icon: Icons.settings_brightness_rounded,
                      title: 'سیستەم',
                      subtitle: 'System',
                      color: Colors.blue,
                      isDark: isDark,
                      itemIndex: 12,
                    ),

                    const SizedBox(height: 20),

                    // ⭐ Notifications
                    _buildSectionTitle(
                      '🔔 ئاگادارکردنەوە',
                      isDark,
                      itemIndex: 13,
                    ),
                    const SizedBox(height: 12),
                    _buildSwitchOption(
                      isDark: isDark,
                      icon: Icons.notifications_active_rounded,
                      title: 'چالاککردنی ئاگادارکردنەوە',
                      subtitle: 'هەموو ئاگادارکردنەوەکان',
                      color: AppColors.primary,
                      value: settings.notificationsEnabled,
                      onChanged: (v) {
                        settings.setNotificationsEnabled(v);
                        _markChanged();
                      },
                      itemIndex: 14,
                    ),
                    _buildSwitchOption(
                      isDark: isDark,
                      icon: Icons.newspaper_rounded,
                      title: 'هەواڵەکان',
                      subtitle: 'ئاگادارکردنەوە بۆ هەواڵی نوێ',
                      color: Colors.blue,
                      value: settings.newsNotifications,
                      enabled: settings.notificationsEnabled,
                      onChanged: (v) {
                        settings.setNewsNotifications(v);
                        _markChanged();
                      },
                      itemIndex: 15,
                    ),
                    _buildSwitchOption(
                      isDark: isDark,
                      icon: Icons.report_rounded,
                      title: 'سکاڵاکان',
                      subtitle: 'ئاگادارکردنەوە بۆ سکاڵاکانت',
                      color: Colors.red,
                      value: settings.complaintNotifications,
                      enabled: settings.notificationsEnabled,
                      onChanged: (v) {
                        settings.setComplaintNotifications(v);
                        _markChanged();
                      },
                      itemIndex: 16,
                    ),
                    _buildSwitchOption(
                      isDark: isDark,
                      icon: Icons.shopping_bag_rounded,
                      title: 'داواکارییەکان',
                      subtitle: 'ئاگادارکردنەوە بۆ ئۆردەرەکانت',
                      color: Colors.green,
                      value: settings.orderNotifications,
                      enabled: settings.notificationsEnabled,
                      onChanged: (v) {
                        settings.setOrderNotifications(v);
                        _markChanged();
                      },
                      itemIndex: 17,
                    ),
                    _buildSwitchOption(
                      isDark: isDark,
                      icon: Icons.volume_up_rounded,
                      title: 'دەنگ',
                      subtitle: 'دەنگی ئاگادارکردنەوە',
                      color: Colors.orange,
                      value: settings.soundEnabled,
                      enabled: settings.notificationsEnabled,
                      onChanged: (v) {
                        settings.setSoundEnabled(v);
                        _markChanged();
                      },
                      itemIndex: 18,
                    ),
                    _buildSwitchOption(
                      isDark: isDark,
                      icon: Icons.vibration_rounded,
                      title: 'لەرینەوە',
                      subtitle: 'لەرینەوەی مۆبایل',
                      color: Colors.teal,
                      value: settings.vibrationEnabled,
                      enabled: settings.notificationsEnabled,
                      onChanged: (v) {
                        settings.setVibrationEnabled(v);
                        _markChanged();
                      },
                      itemIndex: 19,
                    ),

                    const SizedBox(height: 20),

                    // ⭐ Reset
                    _buildResetButton(isDark, settings, itemIndex: 20),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 AppBar
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        if (_hasChanges)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(left: 8),
            child: IconButton(
              icon: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  );
                },
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ هەموو ڕێکخستنەکان پاشەکەوت کران',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
                setState(() => _hasChanges = false);
              },
              tooltip: 'پاشەکەوتکراوە',
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A1A22), const Color(0xFF252530)]
                  : [
                Colors.white,
                AppColors.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -50,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                          AppColors.primary.withValues(alpha: 0.08),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.4,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    Color.lerp(AppColors.primary,
                                        Colors.white, 0.2)!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ڕێکخستنەکان',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'زمان، فۆنت، ڕەنگ، ئاگادارکردنەوە',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
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

  // ═══════════════════════════════════════════════════════════
  // 📊 Quick Info
  // ═══════════════════════════════════════════════════════════
  Widget _buildQuickInfo(
      bool isDark,
      SettingsProvider settings, {
        required int itemIndex,
      }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - progress)),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.primary.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.info_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ڕێکخستنەکان خۆکارانە پاشەکەوت دەکرێن',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'هەر گۆڕانکارییەک دەستبەجێ پاشەکەوت دەکرێت',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? Colors.white54
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Search Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? AppColors.primary.withValues(alpha: 0.4)
              : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim()),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'گەڕان بەدوای ڕێکخستن...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 Section Title
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionTitle(
      String title,
      bool isDark, {
        required int itemIndex,
      }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(
            opacity: progress,
            child: Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 6),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🌍 Language Option
  // ═══════════════════════════════════════════════════════════
  Widget _buildLanguageOption({
    required String languageId,
    required String languageName,
    required String nativeName,
    required String flag,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    required int itemIndex,
  }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                  ? const Color(0xFF2A2A35)
                  : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nativeName,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.white38 : Colors.grey),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔤 Font Dropdown
  // ═══════════════════════════════════════════════════════════
  Widget _buildFontDropdown(
      bool isDark,
      SettingsProvider settings, {
        required int itemIndex,
      }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? const Color(0xFF2A2A35)
                : Colors.grey.shade200,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: settings.fontId,
            isExpanded: true,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            borderRadius: BorderRadius.circular(14),
            dropdownColor:
            isDark ? const Color(0xFF1A1A22) : Colors.white,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary,
            ),
            items: SettingsProvider.availableFonts.map((font) {
              return DropdownMenuItem<String>(
                value: font['id'],
                child: Row(
                  children: [
                    Icon(
                      Icons.text_fields_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      font['name']!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                HapticFeedback.selectionClick();
                settings.setFont(value);
                _markChanged();
              }
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📏 Font Size Option
  // ═══════════════════════════════════════════════════════════
  Widget _buildFontSizeOption({
    required String sizeId,
    required String sizeName,
    required double scale,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    required int itemIndex,
  }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                  ? const Color(0xFF2A2A35)
                  : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.white38 : Colors.grey),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sizeName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Aa',
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.bold,
                  color:
                  isSelected ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 👁️ Preview Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildPreviewCard(
      bool isDark,
      SettingsProvider settings, {
        required int itemIndex,
      }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? const Color(0xFF2A2A35)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ناونیشان — Title',
              style: TextStyle(
                fontSize: 20 * settings.fontScale,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ژێرناونیشان — Subtitle',
              style: TextStyle(
                fontSize: 15 * settings.fontScale,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ئەمە نموونەیەکی نووسینە بۆ پیشاندانی فۆنت و قەبارەکەت. دەتوانیت هەموو شتێک بە ئاسانی بگۆڕیت.',
              style: TextStyle(
                fontSize: 13 * settings.fontScale,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🌙 Theme Option
  // ═══════════════════════════════════════════════════════════
  Widget _buildThemeOption(
      BuildContext context, {
        required ThemeMode mode,
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required bool isDark,
        required int itemIndex,
      }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentMode = themeProvider.themeMode;
    final isSelected = currentMode == mode;

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          themeProvider.setThemeMode(mode);
          _markChanged();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                  ? const Color(0xFF2A2A35)
                  : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.white38 : Colors.grey),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔔 Switch Option
  // ═══════════════════════════════════════════════════════════
  Widget _buildSwitchOption({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool value,
    required Function(bool) onChanged,
    required int itemIndex,
    bool enabled = true,
  }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(
            opacity: progress * (enabled ? 1.0 : 0.4),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? const Color(0xFF2A2A35)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white54
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Reset Button
  // ═══════════════════════════════════════════════════════════
  Widget _buildResetButton(
      bool isDark,
      SettingsProvider settings, {
        required int itemIndex,
      }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - progress)),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _showResetDialog(context, settings, isDark);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restore_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'گەڕاندنەوە بۆ دۆخی سەرەتا',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Reset Dialog
  // ═══════════════════════════════════════════════════════════
  void _showResetDialog(
      BuildContext context,
      SettingsProvider settings,
      bool isDark,
      ) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text(
                'گەڕاندنەوە بۆ دۆخی سەرەتا',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'ئایا دڵنیایت؟ هەموو ڕێکخستنەکان دەگەڕێنەوە بۆ دۆخی سەرەتا.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('پاشگەزبوونەوە'),
            ),
            TextButton(
              onPressed: () async {
                await settings.resetToDefaults();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                setState(() => _hasChanges = false);
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ ڕێکخستنەکان گەڕێنرانەوە',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'بەڵێ، بیگەڕێنەوە',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}