import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// ⚙️ نەخشە و نرخی جێگیر
class AppConstants {
  // 📍 کۆئۆردینەیتی شاری کەلار
  static const double kalarLatitude = 34.6189;
  static const double kalarLongitude = 45.3156;

  // 🗺️ زوومی سەرەتایی نەخشە
  static const double defaultMapZoom = 14.0;

  // 📏 سنووری دووری بۆ پیشاندانی شوێنەکان (بە کیلۆمەتر)
  static const double maxDistanceKm = 50.0;

  // 🖼️ قەبارەی وێنەکان
  static const int maxImageSizeKB = 800;
  static const int imageQuality = 70;
  static const int maxProductImages = 4;
  static const int maxNewsImages = 4;
  static const int maxStoreImages = 3;
  static const int maxComplaintImages = 2;

  // ⏱️ کاتەکان
  static const Duration flashSaleDuration = Duration(hours: 24);
  static const Duration bannerAutoPlayInterval = Duration(seconds: 4);

  // 📱 ناوی ئەپ
  static const String appName = 'ڕێبەری کەلار';

  // ═══════════════════════════════════════════════════════════
  // 📦 وەشانی ئەپ
  // ═══════════════════════════════════════════════════════════
  static String? _cachedVersion;
  static String? _cachedBuildNumber;
  static String? _cachedPackageName;

  static Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _cachedVersion = packageInfo.version;
      _cachedBuildNumber = packageInfo.buildNumber;
      _cachedPackageName = packageInfo.packageName;

      debugPrint(
        '📦 App: $_cachedPackageName v$_cachedVersion+$_cachedBuildNumber',
      );
    } catch (e) {
      debugPrint('⚠️ PackageInfo error: $e');
      _cachedVersion = '1.0.0';
      _cachedBuildNumber = '1';
      _cachedPackageName = 'com.kalar.guide';
    }
  }

  static String get appVersion => _cachedVersion ?? '1.0.0';
  static String get appBuildNumber => _cachedBuildNumber ?? '1';
  static String get packageName => _cachedPackageName ?? 'com.kalar.guide';
  static String get fullVersion => 'v$appVersion+$appBuildNumber';

  /// ✅ پشکنینی وەشانی نوێ
  static Future<bool> hasNewVersion(String serverVersion) async {
    try {
      final current = _parseVersion(appVersion);
      final server = _parseVersion(serverVersion);
      return server > current;
    } catch (e) {
      debugPrint('⚠️ Version check error: $e');
      return false;
    }
  }

  /// 🔢 پارسکردنی وەشان بۆ ژمارە
  ///
  /// ✅ چارەسەرکرا — وەزنی دروست:
  /// - `1.2.3` → `10203`
  /// - `1.3.0` → `10300` ✅
  /// - `2.0.0` → `20000` ✅
  static int _parseVersion(String version) {
    try {
      final parts = version.split('.');
      while (parts.length < 3) {
        parts.add('0');
      }

      final major = int.tryParse(parts[0]) ?? 0;
      final minor = int.tryParse(parts[1]) ?? 0;
      final patch = int.tryParse(parts[2]) ?? 0;

      return major * 10000 + minor * 100 + patch;
    } catch (e) {
      debugPrint('⚠️ Version parse error: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕەنگ و ستایل
  // ═══════════════════════════════════════════════════════════
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);

  // ═══════════════════════════════════════════════════════════
  // 📄 Pagination
  // ═══════════════════════════════════════════════════════════
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ═══════════════════════════════════════════════════════════
  // ⏰ Cache
  // ═══════════════════════════════════════════════════════════
  static const Duration defaultCacheDuration = Duration(minutes: 30);
  static const Duration shortCacheDuration = Duration(minutes: 5);
  static const Duration longCacheDuration = Duration(hours: 6);
}