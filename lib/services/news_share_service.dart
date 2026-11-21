// lib/services/news_share_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/tr.dart';

/// 📤 شێرکردنی هەواڵ: وێنەی یەکەم + ناونیشان + کورتە + بڵاوکەرەوە + ناوی ئەپ
class NewsShareService {
  NewsShareService._();

  /// درێژترین کورتەی دەق لە نامەی شێردا
  static const int summaryLength = 220;

  /// دەقی شێر بە زمانی ئێستای ئەپ (هەموو دەقەکان پێشتر بە tr() وەرگێڕدراون)
  static String buildText({
    required String title,
    String description = '',
    String? publisher,
    int maxSummary = summaryLength,
    String? link,
  }) {
    final b = StringBuffer('📰 ${title.trim()}');
    final summary = _summary(description, maxSummary);
    if (summary.isNotEmpty) b.write('\n\n$summary');
    final p = publisher?.trim() ?? '';
    if (p.isNotEmpty) b.write('\n\n🏛️ $p');
    b.write('\n\n📲 ${tr('ئەپی ڕێبەری کەلار')}');
    final l = link?.trim() ?? '';
    if (l.isNotEmpty) b.write('\n$l');
    return b.toString();
  }

  static String _summary(String text, int max) {
    final s = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length <= max) return s;
    // لە کۆتایی وشەیەک دەیبڕێت، نەک لە ناوەڕاستی وشە
    final cut = s.lastIndexOf(' ', max);
    return '${s.substring(0, cut > max ~/ 2 ? cut : max).trim()}…';
  }

  /// شێرکردن. ئەگەر وێنە دابەزێنرا لەگەڵ دەقەکە دەنێردرێت، ئەگینا تەنها دەق.
  /// true = شێرکرا (بۆ زیادکردنی ژمارەی شێر).
  static Future<bool> share({
    required String text,
    String? imageUrl,
    String? subject,
    Rect? origin,
  }) async {
    final file = await _downloadImage(imageUrl);
    try {
      final ShareResult result;
      if (file != null) {
        result = await Share.shareXFiles([file],
            text: text, subject: subject, sharePositionOrigin: origin);
      } else {
        result = await Share.share(text,
            subject: subject, sharePositionOrigin: origin);
      }
      return result.status != ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('❌ News share error: $e');
      return false;
    }
  }

  static Future<XFile?> _downloadImage(String? url) async {
    if (url == null || !url.startsWith('http')) return null;
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      final type = res.headers['content-type'] ?? 'image/jpeg';
      final ext = type.contains('png')
          ? 'png'
          : type.contains('webp')
              ? 'webp'
              : 'jpg';
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/kalar_news_share.$ext');
      await f.writeAsBytes(res.bodyBytes, flush: true);
      return XFile(f.path, mimeType: type);
    } catch (e) {
      debugPrint('⚠️ News share image skipped: $e');
      return null;
    }
  }

  /// ژمارەی شێر زیاد دەکات و ژمارە نوێیەکە دەگەڕێنێتەوە (null = مایگرەیشن نەکراوە)
  static Future<int?> recordShare(String newsId) async {
    try {
      final res = await Supabase.instance.client
          .rpc('increment_news_shares', params: {'p_news_id': newsId});
      return (res as num?)?.toInt();
    } catch (e) {
      debugPrint('⚠️ increment_news_shares: $e');
      return null;
    }
  }

  /// ژمارەی ئێستای شێر (null = ستوونی shares نییە)
  static Future<int?> fetchShares(String newsId) async {
    try {
      final row = await Supabase.instance.client
          .from('news')
          .select('shares')
          .eq('id', newsId)
          .maybeSingle();
      return (row?['shares'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }
}
