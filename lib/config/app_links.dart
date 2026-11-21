// lib/config/app_links.dart
import '../services/app_control.dart';

/// 🔗 لینکەکانی ئەپ. لە شوێنێک بەڕێوە دەبرێن تا هیچ دۆمەینێکی نەناسراو
/// (کە هی ئێمە نییە) لە دەقی شێردا نەمێنێت.
class AppLinks {
  AppLinks._();

  static const String packageId = 'com.muhammad.kalar.kalar_guide';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=$packageId';

  /// لینکی داگرتن: ئەوەی ئەدمین لە «ناوەندی کۆنترۆڵ» دایناوە، ئەگینا Play Store
  static String get downloadUrl {
    final custom = AppControl.state.value.storeUrl;
    return custom.isNotEmpty ? custom : playStoreUrl;
  }

  /// لینکی کردنەوەی ڕاستەوخۆی شوێن/هەواڵ لە ئەپدا (`open.html` لە GitHub Pages
  /// یان هەر ماڵپەڕێک). ئەگەر ئەدمین دانەنابێت null ـە و تەنها لینکی داگرتن دەنێردرێت.
  ///   type: `place` یان `news`
  static String? openUrl(String type, Object id) {
    final base = AppControl.state.value.shareBase;
    if (base.isEmpty) return null;
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}type=${Uri.encodeQueryComponent(type)}&id=${Uri.encodeQueryComponent('$id')}';
  }

  /// لینکی ناو ئەپ (custom scheme) کە `open.html` و Android بەکاری دەهێنن
  static Uri appUri(String type, Object id) => Uri(scheme: 'kalarguide', host: type, pathSegments: ['$id']);

  /// `kalarguide://place/12` → ('place', '12')
  static (String, String)? parse(Uri uri) {
    if (uri.scheme != 'kalarguide') return null;
    if (!const {'place', 'news'}.contains(uri.host)) return null;
    final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return id.isEmpty ? null : (uri.host, id);
  }
}
