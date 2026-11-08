// test/utils/error_handler_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/utils/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ErrorHandler.getUserMessage', () {
    test('کۆدی Postgres', () {
      expect(ErrorHandler.getUserMessage(const PostgrestException(message: 'm', code: '23505')),
          contains('پێشتر هەیە'));
      expect(ErrorHandler.getUserMessage(const PostgrestException(message: 'm', code: 'PGRST116')),
          contains('نەدۆزرایەوە'));
      expect(ErrorHandler.getUserMessage(const PostgrestException(message: 'm', code: '999')),
          contains('داتابەیس'));
    });

    test('هەڵەی تۆڕ و کات', () {
      expect(ErrorHandler.getUserMessage(Exception('SocketException: failed')),
          contains('ئینتەرنێت'));
      expect(ErrorHandler.getUserMessage(TimeoutException('x')), contains('کاتەکە'));
    });

    test('هەڵەی ناوخۆیی نیشانی بەکارهێنەر نادرێت', () {
      final msg = ErrorHandler.getUserMessage(Exception('secret internal detail'));
      expect(msg, isNot(contains('secret')));
    });
  });
}
