import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/complaints_pdf_service.dart';

List<Map<String, dynamic>> _sample() {
  const titles = [
    'خۆڵ و خاشاک و ژینگە',
    'تاریکی شار و سیفەتی گشتی',
    'کێشەی پچڕانی کارەبا'
  ];
  const auth = [
    'شارەوانی کەلار',
    'قایمقامیەتی قەزای کەلار',
    'بەڕێوەبەرایەتی کارەبای گەرمیان'
  ];
  const st = [
    'completed',
    'completed',
    'completed',
    'rejected',
    'pending',
    'in_progress',
    'completed'
  ];
  return [
    for (var i = 0; i < 14; i++)
      {
        'title': titles[i % 3],
        'responsible_authority': auth[i % 3],
        'status': st[i % st.length],
        'created_at': DateTime(2026, 11, 12)
            .subtract(Duration(days: i * 2))
            .toIso8601String(),
      }
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ComplaintsPdfService', () {
    test('ku() converts digits', () {
      expect(ComplaintsPdfService.ku(2026), '٢٠٢٦');
      expect(ComplaintsPdfService.ku('14%'), '١٤%');
    });

    test('cleanAiLines strips markdown, emoji and unknown symbols', () {
      final lines = ComplaintsPdfService.cleanAiLines(
        '* **کێشەی کارەبا** زۆرترین سکاڵایە 🔥\n- ⚠️ تاریکی شار پێویستی بە چارەسەرە\n\n1. زیاتر ✓ بچێتە سەر ڕۆژانە',
      );
      expect(lines, hasLength(3));
      for (final l in lines) {
        expect(l.contains('*'), isFalse);
        expect(RegExp(r'[\u{1F300}-\u{1FAFF}☀-➿✓]', unicode: true).hasMatch(l),
            isFalse);
      }
      expect(lines.first, contains('کارەبا'));
    });

    test('cleanAiLines respects maxLines and empty input', () {
      expect(
          ComplaintsPdfService.cleanAiLines('a\nbbb\nccc\nddd\neee\nfff',
              maxLines: 2),
          hasLength(2));
      expect(ComplaintsPdfService.cleanAiLines(''), isEmpty);
    });

    test('buildReportBytes produces a multi-page PDF offline', () async {
      final bytes = await ComplaintsPdfService.buildReportBytes(
        complaints: _sample(),
        fromDate: DateTime(2026, 10, 13),
        toDate: DateTime(2026, 11, 12),
        aiLines: const [
          'کێشەی کارەبا زۆرترین سکاڵایە',
          'تاریکی شار پێویستی بە چارەسەرە'
        ],
        now: DateTime(2026, 11, 12),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(5000));
      final out = Platform.environment['PDF_OUT'];
      if (out != null) File(out).writeAsBytesSync(bytes);
    });

    test('buildReportBytes handles empty AI text and a single complaint',
        () async {
      final bytes = await ComplaintsPdfService.buildReportBytes(
        complaints: [_sample().first],
        now: DateTime(2026, 11, 12),
      );
      expect(bytes.length, greaterThan(3000));
    });
  });
}
