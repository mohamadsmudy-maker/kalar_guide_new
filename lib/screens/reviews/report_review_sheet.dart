// lib/screens/reviews/report_review_sheet.dart
import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/review_report_service.dart';

/// 🚩 ڕاپۆرتکردنی هەڵسەنگاندنێک. هۆکار + تێبینی ئارەزوومەندانە.
/// [send] بۆ تاقیکردنەوە دەگۆڕدرێت.
Future<void> showReportReviewSheet(
  BuildContext context, {
  required String reviewId,
  Future<ReportResult> Function(String reviewId, String reason, String? note)? send,
}) async {
  final result = await showModalBottomSheet<ReportResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => ReportReviewSheet(
      reviewId: reviewId,
      send: send ??
          (id, reason, note) =>
              ReviewReportService.report(id, reason, note: note),
    ),
  );
  if (result == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(tr(switch (result) {
      ReportResult.ok => '✅ سوپاس، ڕاپۆرتەکەت گەیشت و پێداچوونەوەی بۆ دەکرێت',
      ReportResult.duplicate => 'پێشتر ئەم کۆمێنتەت ڕاپۆرت کردووە',
      ReportResult.failed => 'ناردن سەرکەوتوو نەبوو، دووبارە هەوڵبدەرەوە',
    })),
    backgroundColor:
        result == ReportResult.failed ? AppColors.red : const Color(0xFF0F9D7A),
  ));
}

class ReportReviewSheet extends StatefulWidget {
  const ReportReviewSheet({super.key, required this.reviewId, required this.send});

  final String reviewId;
  final Future<ReportResult> Function(String reviewId, String reason, String? note) send;

  @override
  State<ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends State<ReportReviewSheet> {
  String? _reason;
  bool _sending = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null || _sending) return;
    setState(() => _sending = true);
    final note = _note.text.trim();
    final r = await widget.send(widget.reviewId, _reason!, note.isEmpty ? null : note);
    if (mounted) Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: AppLang.direction,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.flag_rounded, color: AppColors.red),
                const SizedBox(width: 8),
                Text(tr('ڕاپۆرتکردنی کۆمێنت'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 6),
              Text(
                tr('ئەدمین پێداچوونەوە دەکات و ئەگەر یاسای ئەپەکەی پێشێل کردبێت دەیسڕێتەوە.'),
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: isDark ? Colors.white60 : AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Material(
                color: Colors.transparent,
                child: RadioGroup<String>(
                  groupValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                  child: Column(children: [
                    for (final e in reviewReportReasons.entries)
                      RadioListTile<String>(
                        key: ValueKey('reason-${e.key}'),
                        value: e.key,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(tr(e.value)),
                      ),
                  ]),
                ),
              ),
              TextField(
                controller: _note,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: tr('تێبینی (ئارەزوومەندانە)'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  key: const ValueKey('report-send'),
                  onPressed: _reason == null || _sending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(tr('ناردنی ڕاپۆرت'),
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
