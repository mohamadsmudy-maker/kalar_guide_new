// lib/services/sponsored_slides_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_control.dart';
import 'cache_service.dart';

/// 📢 ڕیکلامێکی بازرگانی لە سلایدی پەیجی سەرەکی
@immutable
class SponsoredSlide {
  const SponsoredSlide({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle = '',
    this.actionType = 'none',
    this.actionValue = '',
    required this.startsOn,
    required this.endsOn,
    this.isActive = true,
    this.displayOrder = 0,
    this.views = 0,
    this.clicks = 0,
  });

  final int id;
  final String title;
  final String subtitle;
  final String imageUrl;

  /// none | phone | whatsapp | url | place
  final String actionType;
  final String actionValue;
  final DateTime startsOn;
  final DateTime endsOn;
  final bool isActive;
  final int displayOrder;
  final int views;
  final int clicks;

  static const List<String> actionTypes = ['none', 'phone', 'whatsapp', 'url', 'place', 'news'];

  /// دوگمەکانی ڕیکلامی «تایبەت» (شوێن و هەواڵ لە هەڵبژاردنەکەوە دێن)
  static const List<String> customActionTypes = ['none', 'phone', 'whatsapp', 'url'];

  static String actionLabel(String type) => switch (type) {
        'phone' => 'پەیوەندی',
        'whatsapp' => 'واتسئاپ',
        'url' => 'بینینی زیاتر',
        'place' => 'بینینی شوێن',
        'news' => 'خوێندنەوە',
        _ => 'بێ دوگمە',
      };

  bool get hasAction => actionType != 'none' && actionValue.trim().isNotEmpty;

  /// ئێستا پیشان دەدرێت؟ (چالاک و لە نێوان ڕۆژی دەستپێک و کۆتاییدا)
  bool isLive(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    return isActive && !d.isBefore(startsOn) && !d.isAfter(endsOn);
  }

  factory SponsoredSlide.fromMap(Map<String, dynamic> m) {
    DateTime day(Object? v) {
      final d = DateTime.tryParse('$v') ?? DateTime(2000);
      return DateTime(d.year, d.month, d.day);
    }

    return SponsoredSlide(
      id: (m['id'] as num).toInt(),
      title: '${m['title'] ?? ''}',
      subtitle: '${m['subtitle'] ?? ''}',
      imageUrl: '${m['image_url'] ?? ''}',
      actionType: '${m['action_type'] ?? 'none'}',
      actionValue: '${m['action_value'] ?? ''}',
      startsOn: day(m['starts_on']),
      endsOn: day(m['ends_on']),
      isActive: m['is_active'] != false,
      displayOrder: (m['display_order'] as num?)?.toInt() ?? 0,
      views: (m['views'] as num?)?.toInt() ?? 0,
      clicks: (m['clicks'] as num?)?.toInt() ?? 0,
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toRow() => {
        'title': title.trim(),
        'subtitle': subtitle.trim().isEmpty ? null : subtitle.trim(),
        'image_url': imageUrl,
        'action_type': actionType,
        'action_value': actionValue.trim().isEmpty ? null : actionValue.trim(),
        'starts_on': _date(startsOn),
        'ends_on': _date(endsOn),
        'is_active': isActive,
        'display_order': displayOrder,
      };

  /// کلیلی سلاید لە ناو لیستی هەواڵەکاندا
  static const String mapKey = '_sponsored';
}

class SponsoredSlidesService {
  SponsoredSlidesService._();

  static SupabaseClient get _db => Supabase.instance.client;
  static const String featureKey = 'sponsored_slides';
  static const String _cacheKey = 'sponsored_slides_v1';

  /// زۆرترین ژمارەی ڕیکلام لە سلایدەکەدا، و دوای چەند هەواڵێک یەک ڕیکلام
  static const int maxInCarousel = 3;
  static const int everyNews = 2;

  static bool get enabled => AppControl.state.value.feature(featureKey);

  /// ڕیکلامە چالاکەکان (بێ ئینتەرنێتیش لە کاشەوە)
  static Future<List<SponsoredSlide>> live() async {
    if (!enabled) return const [];
    try {
      final rows = await CacheService.fetchList(
        _cacheKey,
        () async => List<Map<String, dynamic>>.from(await _db
            .from('sponsored_slides')
            .select()
            .order('display_order')
            .order('id', ascending: false) as List),
        keepFor: const Duration(hours: 6),
      );
      final now = DateTime.now();
      return [
        for (final r in rows)
          if (SponsoredSlide.fromMap(r).isLive(now)) SponsoredSlide.fromMap(r),
      ];
    } catch (e) {
      debugPrint('⚠️ sponsored slides: $e');
      return const [];
    }
  }

  /// دوای هەر [every] هەواڵ یەک ڕیکلام، زۆرترین [max]. ئەگەر هەواڵ نەبوو، تەنها ڕیکلامەکان.
  static List<Map<String, dynamic>> interleave(
    List<Map<String, dynamic>> news,
    List<SponsoredSlide> ads, {
    int every = everyNews,
    int max = maxInCarousel,
  }) {
    final use = ads.take(max).toList();
    if (use.isEmpty) return news;
    Map<String, dynamic> wrap(SponsoredSlide s) =>
        {'id': 'ad-${s.id}', 'title': s.title, SponsoredSlide.mapKey: s};
    if (news.isEmpty) return [for (final s in use) wrap(s)];
    final out = <Map<String, dynamic>>[];
    var a = 0;
    for (var i = 0; i < news.length; i++) {
      out.add(news[i]);
      if ((i + 1) % every == 0 && a < use.length) out.add(wrap(use[a++]));
    }
    while (a < use.length) {
      out.add(wrap(use[a++]));
    }
    return out;
  }

  static final Set<int> _seen = {};

  /// بینین (یەکجار بۆ هەر ڕیکلامێک لە هەر کردنەوەیەکی ئەپ)
  static Future<void> recordView(SponsoredSlide s) async {
    if (!_seen.add(s.id)) return;
    await _event(s.id, 'view');
  }

  static Future<void> recordClick(SponsoredSlide s) => _event(s.id, 'click');

  static Future<void> _event(int id, String kind) async {
    try {
      await _db.rpc('app_sponsored_event', params: {'p_id': id, 'p_kind': kind});
    } catch (_) {}
  }

  /// لینکی دوگمەی ڕیکلام (null = شوێن لە ناو ئەپ / بێ دوگمە)
  static Uri? actionUri(SponsoredSlide s) {
    final v = s.actionValue.trim();
    if (v.isEmpty) return null;
    final digits = v.replaceAll(RegExp(r'[^0-9+]'), '');
    switch (s.actionType) {
      case 'phone':
        return Uri.parse('tel:$digits');
      case 'whatsapp':
        var n = digits.replaceFirst('+', '');
        if (n.startsWith('07')) n = '964${n.substring(1)}';
        return Uri.parse('https://wa.me/$n');
      case 'url':
        return Uri.tryParse(v.startsWith('http') ? v : 'https://$v');
      default:
        return null;
    }
  }

  static Future<void> open(SponsoredSlide s) async {
    unawaited(recordClick(s));
    final uri = actionUri(s);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── ئەدمین ─────────────────────────────────────────────
  static Future<List<SponsoredSlide>> all() async {
    final rows = await _db
        .from('sponsored_slides')
        .select()
        .order('display_order')
        .order('id', ascending: false);
    return [for (final r in rows as List) SponsoredSlide.fromMap(Map<String, dynamic>.from(r as Map))];
  }

  static Future<void> save(SponsoredSlide s, {bool isNew = false}) async {
    if (isNew) {
      await _db.from('sponsored_slides').insert(s.toRow());
    } else {
      await _db.from('sponsored_slides').update(s.toRow()).eq('id', s.id);
    }
    await CacheService.remove(_cacheKey);
  }

  static Future<void> delete(int id) async {
    await _db.from('sponsored_slides').delete().eq('id', id);
    await CacheService.remove(_cacheKey);
  }
}

