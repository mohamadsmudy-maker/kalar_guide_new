// lib/screens/admin/admin_review_reports.dart
//
// 🚩 ئەدمین: کۆمێنتە ڕاپۆرتکراوەکان. هەر کۆمێنتێک یەکجار، لەگەڵ ژمارەی ڕاپۆرت
// و هۆکارەکان. «سڕینەوە» کۆمێنتەکە دەسڕێتەوە؛ «هێشتنەوە» ڕاپۆرتەکان ڕەت
// دەکاتەوە و کۆمێنتەکە (ئەگەر خۆکار شاردرابووەوە) دەگەڕێنێتەوە.

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/review_report_service.dart';

const _red = Color(0xFFDC2626);

class AdminReviewReportsScreen extends StatefulWidget {
  const AdminReviewReportsScreen({super.key, this.loader, this.onDismiss, this.onRemove});

  /// بۆ تاقیکردنەوە
  final Future<List<ReportedReview>> Function()? loader;
  final Future<void> Function(String reviewId)? onDismiss;
  final Future<void> Function(String reviewId)? onRemove;

  @override
  State<AdminReviewReportsScreen> createState() => _AdminReviewReportsScreenState();
}

class _AdminReviewReportsScreenState extends State<AdminReviewReportsScreen> {
  List<ReportedReview>? _items;
  bool _error = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final items = await (widget.loader ?? ReviewReportService.fetchOpen)();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      debugPrint('⚠️ admin review reports: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _act(ReportedReview r, {required bool remove}) async {
    if (remove) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: AppLang.direction,
          child: AlertDialog(
            title: Text(tr('سڕینەوەی کۆمێنت')),
            content: Text(tr('ئایا دڵنیایت لە سڕینەوەی ئەم کۆمێنتە؟')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('پاشگەزبوونەوە'))),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: _red),
                child: Text(tr('سڕینەوە')),
              ),
            ],
          ),
        ),
      );
      if (yes != true) return;
    }
    setState(() => _busy.add(r.reviewId));
    try {
      final fn = remove
          ? (widget.onRemove ?? ReviewReportService.removeReview)
          : (widget.onDismiss ?? ReviewReportService.dismiss);
      await fn(r.reviewId);
      if (!mounted) return;
      setState(() => _items = _items?.where((x) => x.reviewId != r.reviewId).toList());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F9D7A),
        content: Text(tr(remove ? '✅ کۆمێنت سڕایەوە' : 'کۆمێنتەکە هێڵرایەوە')),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('هەڵەیەک ڕوویدا'))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(r.reviewId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(tr('کۆمێنتە ڕاپۆرتکراوەکان'),
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: _error
            ? Center(
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tr('دووبارە هەوڵبدەرەوە')),
                ),
              )
            : items == null
                ? const Center(child: CircularProgressIndicator(color: _red))
                : items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(tr('هیچ ڕاپۆرتێکی نوێ نییە'),
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _card(items[i]),
                        ),
                      ),
      ),
    );
  }

  Widget _card(ReportedReview r) {
    final review = r.review;
    final busy = _busy.contains(r.reviewId);
    final hidden = review != null && review['is_approved'] == false;
    final comment = (review?['comment'] ?? '').toString().trim();
    final name = (review?['user_name'] ?? '').toString().trim();
    final rating = (review?['rating'] as num?)?.toInt() ?? 0;

    return Container(
      key: ValueKey('reported-${r.reviewId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trf('{0} ڕاپۆرت', [AppLang.localDigits('${r.count}')]),
                style: const TextStyle(color: _red, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
            if (hidden) ...[
              const SizedBox(width: 6),
              Text(tr('(شاردراوەتەوە)'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
            ],
            const Spacer(),
            if (rating > 0)
              Text('★' * rating, style: const TextStyle(color: Color(0xFFD9822B), fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          if (review == null)
            Text(tr('کۆمێنتەکە پێشتر سڕاوەتەوە'),
                style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic))
          else ...[
            if (name.isNotEmpty)
              Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(comment, style: const TextStyle(fontSize: 14, height: 1.5)),
            ],
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in r.reasons.entries)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  '${tr(reviewReportReasons[e.key] ?? e.key)} × ${AppLang.localDigits('${e.value}')}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
          ]),
          for (final n in r.notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('💬 $n', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: ValueKey('keep-${r.reviewId}'),
                onPressed: busy ? null : () => _act(r, remove: false),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(tr('هێشتنەوە')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                key: ValueKey('remove-${r.reviewId}'),
                onPressed: busy || review == null ? null : () => _act(r, remove: true),
                style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
                icon: const Icon(Icons.delete_rounded, size: 18),
                label: Text(tr('سڕینەوە')),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
