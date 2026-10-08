import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide/utils/date_picker_helper.dart';

void main() {
  group('DatePickerHelper', () {
    test('getLocaleForLanguage دەبێت دروست کار بکات', () {
      expect(
        DatePickerHelper.getLocaleForLanguage('ku'),
        equals(const Locale('ar', 'AE')),
      );

      expect(
        DatePickerHelper.getLocaleForLanguage('ar'),
        equals(const Locale('ar', 'AE')),
      );

      expect(
        DatePickerHelper.getLocaleForLanguage('en'),
        equals(const Locale('en', 'US')),
      );
    });

    test('زمانی نەناسراو دەبێت ar_AE بگەڕێنێتەوە', () {
      expect(
        DatePickerHelper.getLocaleForLanguage('xyz'),
        equals(const Locale('ar', 'AE')),
      );

      expect(
        DatePickerHelper.getLocaleForLanguage(''),
        equals(const Locale('ar', 'AE')),
      );
    });
  });
}