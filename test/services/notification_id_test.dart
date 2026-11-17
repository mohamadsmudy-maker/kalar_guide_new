import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/notification_service.dart';

void main() {
  test('هەمان هەواڵی بەپەلە (topic + token) یەک ئاگاداری دەبێت', () {
    final a = NotificationService.notificationId({'tag': 'breaking-7'}, 1);
    final b = NotificationService.notificationId({'tag': 'breaking-7'}, 2);
    expect(a, b);
    expect(a, isNonNegative);
    expect(NotificationService.notificationId({'tag': 'breaking-8'}, 1), isNot(a));
  });

  test('بێ tag هەمان ژمارەی پێشوو بەکاردێت', () {
    expect(NotificationService.notificationId({}, 42), 42);
    expect(NotificationService.notificationId({'tag': ''}, 42), 42);
  });

  test('topic لەگەڵ فەنکشنەکەی سێرڤەر یەکە', () {
    expect(NotificationService.breakingNewsTopic, 'breaking_news');
  });
}
