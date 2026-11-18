import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/utils/error_reporter.dart';

void main() {
  group('ErrorReporter.shouldReport', () {
    test('هەڵەی تۆڕ نانێردرێت', () {
      expect(ErrorReporter.shouldReport(const SocketException('x')), isFalse);
      expect(ErrorReporter.shouldReport(TimeoutException('x')), isFalse);
      expect(ErrorReporter.shouldReport(const HandshakeException('x')), isFalse);
      expect(
          ErrorReporter.shouldReport(
              Exception('ClientException: Failed host lookup: api')),
          isFalse);
      expect(ErrorReporter.shouldReport(Exception('Connection reset by peer')),
          isFalse);
    });

    test('هەڵەی ڕاستەقینەی ئەپ دەنێردرێت', () {
      expect(ErrorReporter.shouldReport(StateError('bad state')), isTrue);
      expect(ErrorReporter.shouldReport(const FormatException('bad')), isTrue);
      expect(ErrorReporter.shouldReport(RangeError(3)), isTrue);
    });
  });

  test('لە debug/تاقیکردنەوە ناچالاکە و هیچ تێکناچێت', () async {
    await ErrorReporter.initialize();
    expect(ErrorReporter.enabled, isFalse);
    await ErrorReporter.recordError(StateError('x'), StackTrace.current);
    ErrorReporter.log('x');
    await ErrorReporter.setUserId('u');
  });
}
