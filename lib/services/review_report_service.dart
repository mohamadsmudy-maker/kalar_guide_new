// lib/services/review_report_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// هۆکارەکانی ڕاپۆرت (کلیل → دەقی کوردی، بۆ tr())
const Map<String, String> reviewReportReasons = {
  'offensive': 'جنێو یان ناوەڕۆکی ناشیرین',
  'spam': 'ڕیکلام یان سپام',
  'false': 'زانیاریی هەڵە یان درۆ',
  'personal': 'زانیاریی کەسیی کەسێکی تر',
  'other': 'هۆکاری تر',
};

enum ReportResult { ok, duplicate, failed }

/// یەک هەڵسەنگاندنی ڕاپۆرتکراو لەگەڵ ڕاپۆرتەکانی (بۆ ئەدمین)
class ReportedReview {
  ReportedReview({
    required this.reviewId,
    required this.storeId,
    required this.reasons,
    required this.notes,
    required this.count,
    required this.lastAt,
    this.review,
  });

  final String reviewId;
  final int? storeId;
  final Map<String, int> reasons;
  final List<String> notes;
  final int count;
  final DateTime lastAt;
  final Map<String, dynamic>? review;

  /// ڕاپۆرتە کراوەکان بە هەڵسەنگاندن کۆدەکاتەوە، نوێترین لە سەرەوە
  static List<ReportedReview> group(
    List<Map<String, dynamic>> reports,
    Map<String, Map<String, dynamic>> reviews,
  ) {
    final by = <String, List<Map<String, dynamic>>>{};
    for (final r in reports) {
      by.putIfAbsent(r['review_id'].toString(), () => []).add(r);
    }
    final out = [
      for (final e in by.entries)
        ReportedReview(
          reviewId: e.key,
          storeId: (e.value.first['store_id'] as num?)?.toInt(),
          reasons: {
            for (final r in e.value)
              r['reason'].toString(): e.value
                  .where((x) => x['reason'] == r['reason'])
                  .length,
          },
          notes: [
            for (final r in e.value)
              if ((r['note'] ?? '').toString().trim().isNotEmpty)
                r['note'].toString().trim(),
          ],
          count: e.value.length,
          lastAt: e.value
              .map((r) =>
                  DateTime.tryParse(r['created_at']?.toString() ?? '') ??
                  DateTime(2000))
              .reduce((a, b) => a.isAfter(b) ? a : b),
          review: reviews[e.key],
        ),
    ]..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return out;
  }
}

class ReviewReportService {
  ReviewReportService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<ReportResult> report(String reviewId, String reason,
      {String? note}) async {
    try {
      final res = await _db.rpc('app_report_review', params: {
        'p_review_id': reviewId,
        'p_reason': reason,
        'p_note': note,
      });
      return switch (res) {
        'ok' => ReportResult.ok,
        'duplicate' => ReportResult.duplicate,
        _ => ReportResult.failed,
      };
    } catch (e) {
      debugPrint('❌ report review: $e');
      return ReportResult.failed;
    }
  }

  /// ئەدمین: هەڵسەنگاندنە ڕاپۆرتکراوەکان (تەنها ڕاپۆرتی کراوە)
  static Future<List<ReportedReview>> fetchOpen() async {
    final reports = List<Map<String, dynamic>>.from(await _db
        .from('review_reports')
        .select()
        .eq('status', 'open')
        .order('created_at', ascending: false));
    final ids = {for (final r in reports) r['review_id'].toString()}.toList();
    final reviews = <String, Map<String, dynamic>>{};
    if (ids.isNotEmpty) {
      final rows = await _db.from('reviews').select().inFilter('id', ids);
      for (final r in rows as List) {
        final m = Map<String, dynamic>.from(r as Map);
        reviews[m['id'].toString()] = m;
      }
    }
    return ReportedReview.group(reports, reviews);
  }

  /// ئەدمین: ڕاپۆرتەکان ڕەت دەکاتەوە و هەڵسەنگاندنەکە دەگەڕێنێتەوە
  static Future<void> dismiss(String reviewId) async {
    await _db
        .from('review_reports')
        .update({'status': 'dismissed'})
        .eq('review_id', reviewId)
        .eq('status', 'open');
    await _db.from('reviews').update({'is_approved': true}).eq('id', reviewId);
  }

  /// ئەدمین: هەڵسەنگاندنەکە دەسڕێتەوە
  static Future<void> removeReview(String reviewId) async {
    await _db
        .from('review_reports')
        .update({'status': 'removed'})
        .eq('review_id', reviewId)
        .eq('status', 'open');
    await _db.from('reviews').delete().eq('id', reviewId);
  }
}
