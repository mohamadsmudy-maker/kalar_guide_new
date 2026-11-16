import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// بڕی ئێستا و بڕی ماوەی پێشوو — بۆ نیشاندانی بەرزبوونەوە/دابەزین
@immutable
class StatPair {
  const StatPair(this.now, this.prev);
  final int now;
  final int prev;

  /// ڕێژەی گۆڕان بە %؛ null ئەگەر پێشوو سفر بێت و ئێستا سفر نەبێت (بێ بەراورد)
  double? get deltaPct {
    if (prev == 0) return now == 0 ? 0 : null;
    return (now - prev) / prev * 100;
  }
}

@immutable
class NamedCount {
  const NamedCount(this.name, this.n);
  final String name;
  final int n;
}

@immutable
class DayPoint {
  const DayPoint(this.day, this.n);
  final DateTime day;
  final int n;
}

/// ئەنجامی `app_admin_stats(days)`. هەر بەشێک null بێت یانی لەم پڕۆژەیەدا نییە.
@immutable
class AdminStats {
  const AdminStats({
    required this.days,
    this.totals,
    this.complaints,
    this.complaintsDaily = const [],
    this.complaintStatus = const {},
    this.topNeighborhoods = const [],
    this.topAuthorities = const [],
    this.pendingComplaints = 0,
    this.resolvedComplaints = 0,
    this.avgResolutionHours,
    this.users,
    this.usersDaily = const [],
    this.byRole = const {},
    this.byLanguage = const {},
    this.byPlatform = const {},
    this.online,
    this.places,
    this.categories = const [],
    this.topRated = const [],
    this.topFavorited = const [],
    this.topNews = const [],
    this.topEvents = const [],
    this.search,
    this.topQueries = const [],
    this.noResults = const [],
    this.hasContent = false,
  });

  final int days;
  final Map<String, int>? totals;

  final StatPair? complaints;
  final List<DayPoint> complaintsDaily;
  final Map<String, int> complaintStatus;
  final List<NamedCount> topNeighborhoods;
  final List<NamedCount> topAuthorities;
  final int pendingComplaints;
  final int resolvedComplaints;
  final double? avgResolutionHours;

  final StatPair? users;
  final List<DayPoint> usersDaily;
  final Map<String, int> byRole;
  final Map<String, int> byLanguage;
  final Map<String, int> byPlatform;
  final int? online;

  final StatPair? places;
  final List<NamedCount> categories;
  final List<NamedCount> topRated;
  final List<NamedCount> topFavorited;

  final bool hasContent;
  final List<NamedCount> topNews;
  final List<NamedCount> topEvents;

  final StatPair? search;
  final List<NamedCount> topQueries;
  final List<NamedCount> noResults;

  /// ڕێژەی سکاڵا چارەسەرکراوەکان لەو ماوەیەدا (٠-١٠٠)
  double? get resolvedRate {
    final c = complaints;
    if (c == null || c.now == 0) return null;
    return (resolvedComplaints / c.now * 100).clamp(0, 100).toDouble();
  }

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static StatPair? _pair(dynamic m) =>
      m is Map ? StatPair(_i(m['now']), _i(m['prev'])) : null;

  static Map<String, int> _map(dynamic m) => m is Map
      ? {for (final e in m.entries) '${e.key}': _i(e.value)}
      : const {};

  static List<NamedCount> _named(dynamic l, {String count = 'n'}) => l is List
      ? [
          for (final e in l)
            if (e is Map) NamedCount('${e['name'] ?? ''}', _i(e[count])),
        ]
      : const [];

  static List<DayPoint> _daily(dynamic l) => l is List
      ? [
          for (final e in l)
            if (e is Map && DateTime.tryParse('${e['d']}') != null)
              DayPoint(DateTime.parse('${e['d']}'), _i(e['n'])),
        ]
      : const [];

  factory AdminStats.fromJson(Map<String, dynamic> j) {
    final c = j['complaints'];
    final u = j['users'];
    final p = j['places'];
    final ct = j['content'];
    final s = j['search'];
    return AdminStats(
      days: _i(j['days']),
      totals: j['totals'] is Map ? _map(j['totals']) : null,
      complaints: _pair(c),
      complaintsDaily: c is Map ? _daily(c['daily']) : const [],
      complaintStatus: c is Map ? _map(c['by_status']) : const {},
      topNeighborhoods: c is Map ? _named(c['top_neighborhoods']) : const [],
      topAuthorities: c is Map ? _named(c['top_authorities']) : const [],
      pendingComplaints: c is Map ? _i(c['pending']) : 0,
      resolvedComplaints: c is Map ? _i(c['resolved']) : 0,
      avgResolutionHours:
          c is Map && c['avg_resolution_hours'] != null ? (c['avg_resolution_hours'] as num).toDouble() : null,
      users: _pair(u),
      usersDaily: u is Map ? _daily(u['daily']) : const [],
      byRole: u is Map ? _map(u['by_role']) : const {},
      byLanguage: u is Map ? _map(u['by_language']) : const {},
      byPlatform: u is Map ? _map(u['by_platform']) : const {},
      online: u is Map && u['online'] != null ? _i(u['online']) : null,
      places: _pair(p),
      categories: p is Map ? _named(p['by_category']) : const [],
      topRated: p is Map ? _named(p['top_rated'], count: 'reviews') : const [],
      topFavorited: p is Map ? _named(p['top_favorited']) : const [],
      hasContent: ct is Map,
      topNews: ct is Map ? _named(ct['top_news'], count: 'views') : const [],
      topEvents: ct is Map ? _named(ct['top_events'], count: 'views') : const [],
      search: _pair(s),
      topQueries: s is Map ? _named(s['top']) : const [],
      noResults: s is Map ? _named(s['no_results']) : const [],
    );
  }

  /// پوختەی دەقی بۆ شەیرکردن (واتسئاپ)
  String summary(String Function(String) t) {
    final b = StringBuffer('📊 ${t('ڕاپۆرتی ئەپ')} — ${t('دوایین')} $days ${t('ڕۆژ')}\n');
    final c = complaints;
    if (c != null) b.writeln('• ${t('سکاڵای نوێ')}: ${c.now}  (${t('چاوەڕوان')}: $pendingComplaints)');
    final u = users;
    if (u != null) b.writeln('• ${t('بەکارهێنەری نوێ')}: ${u.now}');
    final p = places;
    if (p != null) b.writeln('• ${t('شوێنی نوێ')}: ${p.now}');
    final s = search;
    if (s != null) b.writeln('• ${t('گەڕانەکان')}: ${s.now}');
    if (noResults.isNotEmpty) {
      b.writeln('• ${t('گەڕانی بێ ئەنجام')}: ${noResults.take(5).map((e) => e.name).join('، ')}');
    }
    return b.toString().trim();
  }
}

/// هێنانی ئامار لە سێرڤەر
class AdminStatsService {
  AdminStatsService._();

  static Future<AdminStats> fetch(int days) async {
    final res = await Supabase.instance.client
        .rpc('app_admin_stats', params: {'p_days': days});
    return AdminStats.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// گەڕانێک تۆمار دەکات (بێ ناسنامە). هەرگیز هەڵە ناگەڕێنێتەوە.
  static Future<void> logSearch(String query, int results, String lang) async {
    final q = query.trim();
    if (q.length < 2 || RegExp(r'\d{7,}').hasMatch(q)) return; // ژمارەی مۆبایل/ناسنامە نا
    try {
      await Supabase.instance.client.rpc('app_log_search',
          params: {'p_q': q, 'p_results': results, 'p_lang': lang});
    } catch (e) {
      debugPrint('⚠️ log search: $e');
    }
  }
}
