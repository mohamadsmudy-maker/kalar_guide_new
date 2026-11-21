import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/notification_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('master switch turns everything off', () {
    const p = NotificationPrefs(enabled: false);
    expect(p.allows('breaking_news'), isFalse);
    expect(p.allows('complaint_status'), isFalse);
    expect(p.wantsNeighborhoodAlerts, isFalse);
  });

  test('per-type switches', () {
    const p = NotificationPrefs(breakingNews: false);
    expect(p.allows('breaking_news'), isFalse);
    expect(p.allows('complaint_status'), isTrue);
    expect(p.allows('neighborhood_alert'), isTrue);
    expect(const NotificationPrefs(complaints: false).allows('complaint'), isFalse);
  });

  test('loads the same keys as settings', () async {
    SharedPreferences.setMockInitialValues({'news_notifications': false});
    final p = await NotificationPrefs.load();
    expect(p.wantsBreakingNews, isFalse);
    expect(p.wantsComplaints, isTrue);
  });
}
