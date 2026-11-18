import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/admin_review_reports.dart';
import 'package:kalar_guide_new/screens/reviews/report_review_sheet.dart';
import 'package:kalar_guide_new/services/review_report_service.dart';

void main() {
  test('ڕاپۆرتەکان بە کۆمێنت کۆدەکرێنەوە', () {
    final g = ReportedReview.group([
      {'review_id': '7', 'store_id': 1, 'reason': 'spam', 'note': 'ڕیکلامە', 'created_at': '2026-11-18T10:00:00Z'},
      {'review_id': '7', 'store_id': 1, 'reason': 'spam', 'note': null, 'created_at': '2026-11-18T12:00:00Z'},
      {'review_id': '7', 'store_id': 1, 'reason': 'offensive', 'note': '', 'created_at': '2026-11-18T11:00:00Z'},
      {'review_id': '9', 'store_id': 2, 'reason': 'false', 'note': null, 'created_at': '2026-11-17T09:00:00Z'},
    ], {
      '7': {'id': 7, 'comment': 'x'},
    });
    expect(g.map((r) => r.reviewId), ['7', '9']); // نوێترین لە سەرەوە
    expect(g.first.count, 3);
    expect(g.first.reasons, {'spam': 2, 'offensive': 1});
    expect(g.first.notes, ['ڕیکلامە']);
    expect(g.first.review, isNotNull);
    expect(g.last.review, isNull);
  });

  testWidgets('ڕاپۆرتکردن: هۆکار پێویستە، پاشان دەنێردرێت', (tester) async {
    String? sentReason;
    String? sentNote;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => showReportReviewSheet(c, reviewId: '7', send: (id, reason, note) async {
              sentReason = reason;
              sentNote = note;
              return ReportResult.ok;
            }),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final send = find.byKey(const ValueKey('report-send'));
    expect(tester.widget<ElevatedButton>(send).onPressed, isNull, reason: 'no reason yet');

    await tester.tap(find.byKey(const ValueKey('reason-offensive')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  جنێوی تێدایە ');
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(sentReason, 'offensive');
    expect(sentNote, 'جنێوی تێدایە');
    expect(find.byType(ReportReviewSheet), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('ئەدمین: هێشتنەوە و سڕینەوە', (tester) async {
    final dismissed = <String>[];
    final removed = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: AdminReviewReportsScreen(
        loader: () async => ReportedReview.group([
          {'review_id': '1', 'reason': 'spam', 'created_at': '2026-11-18T10:00:00Z'},
          {'review_id': '2', 'reason': 'offensive', 'created_at': '2026-11-18T09:00:00Z'},
        ], {
          '1': {'id': 1, 'comment': 'یەکەم', 'user_name': 'ئاراس', 'rating': 1, 'is_approved': true},
          '2': {'id': 2, 'comment': 'دووەم', 'user_name': 'شوان', 'rating': 2, 'is_approved': false},
        }),
        onDismiss: (id) async => dismissed.add(id),
        onRemove: (id) async => removed.add(id),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('یەکەم'), findsOneWidget);
    expect(find.text('(شاردراوەتەوە)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('keep-1')));
    await tester.pumpAndSettle();
    expect(dismissed, ['1']);
    expect(find.text('یەکەم'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('remove-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('سڕینەوە').last); // پشتڕاستکردنەوە
    await tester.pumpAndSettle();
    expect(removed, ['2']);
    expect(find.text('هیچ ڕاپۆرتێکی نوێ نییە'), findsOneWidget);
  });
}
