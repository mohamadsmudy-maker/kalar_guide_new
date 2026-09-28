import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../config/theme_provider.dart';

/// ⚙️ شاشەی ڕێکخستن (PRO Edition)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'ڕێکخستنەکان',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
          foregroundColor: isDark ? Colors.white : AppColors.primary,
          elevation: 0,
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ═══════════════════════════════════════════════
            // 🌍 بەشی زمان
            // ═══════════════════════════════════════════════
            _buildSection(
              title: '🌍 زمان',
              isDark: isDark,
              child: Column(
                children: SettingsProvider.availableLanguages.map((lang) {
                  final isSelected = settings.languageId == lang['id'];
                  return _buildLanguageOption(
                    languageId: lang['id']!,
                    languageName: lang['name']!,
                    nativeName: lang['native']!,
                    flag: lang['flag']!,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () => settings.setLanguage(lang['id']!),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 🔤 بەشی فۆنت
            // ═══════════════════════════════════════════════
            _buildSection(
              title: '🔤 جۆری فۆنت',
              isDark: isDark,
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
                        child: Text(
                          font['name']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) settings.setFont(value);
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 📏 بەشی قەبارەی فۆنت
            // ═══════════════════════════════════════════════
            _buildSection(
              title: '📏 قەبارەی فۆنت',
              isDark: isDark,
              child: Column(
                children: SettingsProvider.availableFontSizes.map((size) {
                  final isSelected = settings.fontSizeId == size['id'];
                  return _buildFontSizeOption(
                    sizeId: size['id']!,
                    sizeName: size['name']!,
                    scale: (size['scale'] as num).toDouble(),
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () => settings.setFontSize(size['id']!),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 👁️ پێشبینین
            // ═══════════════════════════════════════════════
            _buildSection(
              title: '👁️ پێشبینین',
              isDark: isDark,
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
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 🌙 بەشی ڕەنگ
            // ═══════════════════════════════════════════════
            _buildSection(
              title: '🌙 ڕەنگی ئەپ',
              isDark: isDark,
              child: Column(
                children: [
                  _buildThemeOption(
                    context,
                    mode: ThemeMode.light,
                    icon: Icons.light_mode_rounded,
                    title: 'ڕووناک (Light)',
                    color: Colors.orange,
                    isDark: isDark,
                  ),
                  _buildThemeOption(
                    context,
                    mode: ThemeMode.dark,
                    icon: Icons.dark_mode_rounded,
                    title: 'تاریک (Dark)',
                    color: Colors.purple,
                    isDark: isDark,
                  ),
                  _buildThemeOption(
                    context,
                    mode: ThemeMode.system,
                    icon: Icons.settings_brightness_rounded,
                    title: 'سیستەم (System)',
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 🔔 بەشی ئاگادارکردنەوە
            // ═══════════════════════════════════════════════
            _buildSection(
              title: '🔔 ئاگادارکردنەوە',
              isDark: isDark,
              child: Column(
                children: [
                  // ✅ ئاگادارکردنەوەی گشتی
                  _buildSwitchOption(
                    icon: Icons.notifications_active_rounded,
                    title: 'چالاککردنی ئاگادارکردنەوە',
                    subtitle: 'هەموو ئاگادارکردنەوەکان',
                    color: AppColors.primary,
                    value: settings.notificationsEnabled,
                    isDark: isDark,
                    onChanged: (value) =>
                        settings.setNotificationsEnabled(value),
                  ),

                  // 📰 هەواڵەکان
                  _buildSwitchOption(
                    icon: Icons.newspaper_rounded,
                    title: 'هەواڵەکان',
                    subtitle: 'ئاگادارکردنەوە بۆ هەواڵی نوێ',
                    color: Colors.blue,
                    value: settings.newsNotifications,
                    isDark: isDark,
                    enabled: settings.notificationsEnabled,
                    onChanged: (value) => settings.setNewsNotifications(value),
                  ),

                  // 📝 سکاڵاکان
                  _buildSwitchOption(
                    icon: Icons.report_rounded,
                    title: 'سکاڵاکان',
                    subtitle: 'ئاگادارکردنەوە بۆ سکاڵاکانت',
                    color: Colors.red,
                    value: settings.complaintNotifications,
                    isDark: isDark,
                    enabled: settings.notificationsEnabled,
                    onChanged: (value) =>
                        settings.setComplaintNotifications(value),
                  ),

                  // 🛒 داواکارییەکان
                  _buildSwitchOption(
                    icon: Icons.shopping_bag_rounded,
                    title: 'داواکارییەکان',
                    subtitle: 'ئاگادارکردنەوە بۆ ئۆردەرەکانت',
                    color: Colors.green,
                    value: settings.orderNotifications,
                    isDark: isDark,
                    enabled: settings.notificationsEnabled,
                    onChanged: (value) => settings.setOrderNotifications(value),
                  ),

                  // 🔇 دەنگ
                  _buildSwitchOption(
                    icon: Icons.volume_up_rounded,
                    title: 'دەنگ',
                    subtitle: 'دەنگی ئاگادارکردنەوە',
                    color: Colors.orange,
                    value: settings.soundEnabled,
                    isDark: isDark,
                    enabled: settings.notificationsEnabled,
                    onChanged: (value) => settings.setSoundEnabled(value),
                  ),

                  // 📳 لەرینەوە
                  _buildSwitchOption(
                    icon: Icons.vibration_rounded,
                    title: 'لەرینەوە',
                    subtitle: 'لەرینەوەی مۆبایل',
                    color: Colors.teal,
                    value: settings.vibrationEnabled,
                    isDark: isDark,
                    enabled: settings.notificationsEnabled,
                    onChanged: (value) => settings.setVibrationEnabled(value),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // 🔄 گەڕاندنەوە بۆ دۆخی سەرەتا
            // ═══════════════════════════════════════════════
            GestureDetector(
              onTap: () => _showResetDialog(context, settings, isDark),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
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

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 🎨 Helper Widgets
  // ═══════════════════════════════════════════════════

  Widget _buildSection({
    required String title,
    required Widget child,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        child,
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // 🌍 زمان
  // ═══════════════════════════════════════════════════
  Widget _buildLanguageOption({
    required String languageId,
    required String languageName,
    required String nativeName,
    required String flag,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nativeName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
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
                size: 16,
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 📏 قەبارە
  // ═══════════════════════════════════════════════════
  Widget _buildFontSizeOption({
    required String sizeId,
    required String sizeName,
    required double scale,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
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
                size: 16,
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
                color: isSelected ? AppColors.primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 🌙 ڕەنگ
  // ═══════════════════════════════════════════════════
  Widget _buildThemeOption(
      BuildContext context, {
        required ThemeMode mode,
        required IconData icon,
        required String title,
        required Color color,
        required bool isDark,
      }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentMode = themeProvider.themeMode;
    final isSelected = currentMode == mode;

    return GestureDetector(
      onTap: () => themeProvider.setThemeMode(mode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
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
                size: 16,
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 🔔 ئاگادارکردنەوە
  // ═══════════════════════════════════════════════════
  Widget _buildSwitchOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool value,
    required bool isDark,
    required Function(bool) onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A35) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
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
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 🔄 گەڕاندنەوە
  // ═══════════════════════════════════════════════════
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
          title: const Text(
            'گەڕاندنەوە بۆ دۆخی سەرەتا',
            style: TextStyle(fontWeight: FontWeight.bold),
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
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ڕێکخستنەکان گەڕێنرانەوە ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
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