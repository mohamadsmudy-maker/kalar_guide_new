// lib/services/notification_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

/// 🔔 ڕێکخستنی ئاگادارکردنەوە بەپێی جۆر (هەمان کلیلەکانی SettingsProvider)
class NotificationPrefs {
  const NotificationPrefs({this.enabled = true, this.breakingNews = true, this.complaints = true});

  final bool enabled;
  final bool breakingNews;
  final bool complaints;

  bool get wantsBreakingNews => enabled && breakingNews;
  bool get wantsComplaints => enabled && complaints;

  /// ئاگاداریی گەڕەک تەنها بە دوگمە سەرەکییەکە دەکوژێتەوە؛ هەر گەڕەکێک
  /// لە پەڕەی خۆیدا چالاک/ناچالاک دەکرێت.
  bool get wantsNeighborhoodAlerts => enabled;

  static Future<NotificationPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return NotificationPrefs(
      enabled: p.getBool('notifications_enabled') ?? true,
      breakingNews: p.getBool('news_notifications') ?? true,
      complaints: p.getBool('complaint_notifications') ?? true,
    );
  }

  /// ئایا ئاگادارییەکی ئەم جۆرە (data.type) لە کاتی کراوەیی ئەپدا پیشان بدرێت؟
  bool allows(String? type) {
    if (!enabled) return false;
    switch (type) {
      case 'breaking_news':
        return breakingNews;
      case 'complaint':
      case 'complaint_status':
        return complaints;
      default:
        return true;
    }
  }
}
