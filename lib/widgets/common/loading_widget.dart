import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';

/// ⏳ ویجێتی چاوەڕوانی — v2
///
///  • Semantics (liveRegion) بۆ screen reader
///  • `size` و `strokeWidth` ی ئارەزوومەندانە
///  • mainAxisSize.min (پێشتر هەموو بەرزییەکەی دەگرت)
class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;
  final double strokeWidth;

  const LoadingWidget({
    super.key,
    this.message,
    this.color,
    this.size = 36,
    this.strokeWidth = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Semantics(
        liveRegion: true,
        label: message ?? 'Loading',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                color: color ?? AppColors.primary,
                strokeWidth: strokeWidth,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ❌ ویجێتی هەڵە — ✅ ناوی گشتی AppErrorWidget
/// (ناوی ErrorWidget ی Flutter ـە، نابێت بەکاربهێنین)
///
/// زیادکراو: دوگمەی دووبارە بە پێی زمان (پێشتر هەمیشە کوردی)،
/// `retryLabel` / `icon` ی ئارەزوومەندانە، تیمی تاریک
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final IconData icon;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline_rounded,
  });

  static const Map<String, String> _retry = {
    'ku': 'دووبارە هەوڵبدە',
    'ar': 'إعادة المحاولة',
    'en': 'Try again',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.select<SettingsProvider, String>((s) => s.languageId);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onRetry!();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel ?? _retry[lang] ?? _retry['en']!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 📭 ویجێتی بەتاڵ
///
/// زیادکراو: `subtitle` و `action` (بۆ نموونە دوگمەی «زیادکردن»)، تیمی تاریک
class EmptyWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? subtitle;
  final Widget? action;

  const EmptyWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 70,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}