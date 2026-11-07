// lib/screens/weather/weather_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../config/translations.dart';
import '../../services/weather_service.dart';
import '../../widgets/weather_widget.dart';

/// ☁️ شاشەی کەشوهەوا — Ultra Pro Max
class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  static const Map<String, String> _refreshTip = {
    'ku': 'نوێکردنەوە',
    'ar': 'تحديث',
    'en': 'Refresh',
  };

  Future<void> _refresh() {
    HapticFeedback.mediumImpact();
    return WeatherService.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.select<SettingsProvider, String>((s) => s.languageId);
    final isEn = lang == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          title: Text(
            AppTranslations.t('weather', lang),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: WeatherService.instance.refreshing,
              builder: (context, busy, _) => IconButton(
                tooltip: _refreshTip[lang] ?? _refreshTip['en'],
                onPressed: busy ? null : () => unawaited(_refresh()),
                icon: busy
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            // ویجێتەکە خۆی margin ـی ئاسۆیی 16 ی هەیە
            padding: EdgeInsets.only(top: 16, bottom: 40),
            child: WeatherWidget(full: true),
          ),
        ),
      ),
    );
  }
}