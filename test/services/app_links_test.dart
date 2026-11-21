import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/config/app_links.dart';
import 'package:kalar_guide_new/services/app_control.dart';
import 'package:kalar_guide_new/services/news_share_service.dart';

void main() {
  tearDown(() => AppControl.state.value = const AppControlState());

  test('download link falls back to Play Store', () {
    expect(AppLinks.downloadUrl, AppLinks.playStoreUrl);
    expect(AppLinks.openUrl('place', 12), isNull);
  });

  test('admin links from app_settings (https only)', () {
    final s = AppControlState.fromRows([
      {'key': 'app_links', 'value': {'store_url': 'https://example.org/app', 'share_base': 'https://x.github.io/k/open.html'}},
    ]);
    AppControl.state.value = s;
    expect(AppLinks.downloadUrl, 'https://example.org/app');
    expect(AppLinks.openUrl('place', 12), 'https://x.github.io/k/open.html?type=place&id=12');
    expect(AppControlState.fromRows([
      {'key': 'app_links', 'value': {'store_url': 'http://insecure'}},
    ]).storeUrl, isEmpty);
  });

  test('parse app links', () {
    expect(AppLinks.parse(Uri.parse('kalarguide://place/12')), ('place', '12'));
    expect(AppLinks.parse(Uri.parse('kalarguide://news/abc-1')), ('news', 'abc-1'));
    expect(AppLinks.parse(Uri.parse('kalarguide://admin/1')), isNull);
    expect(AppLinks.parse(Uri.parse('https://evil/place/1')), isNull);
    expect(AppLinks.appUri('place', 7).toString(), 'kalarguide://place/7');
  });

  test('news share text carries the link', () {
    final t = NewsShareService.buildText(title: 'x', link: 'https://l');
    expect(t.endsWith('https://l'), isTrue);
  });
}
