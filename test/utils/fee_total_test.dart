import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/utils/fee_total.dart';

void main() {
  group('FeeTotal.amountOf', () {
    test('دوایین ژمارەی دێڕ بڕەکەیە', () {
      expect(FeeTotal.amountOf('پشکنینی چاو: 15000'), 15000);
      expect(FeeTotal.amountOf('وەسڵی 3 دانە: 25000'), 25000);
      expect(FeeTotal.amountOf('تێچووی کارتی مۆڵەتی لێخورین: 20000'), 20000);
    });

    test('ژمارەی کوردی و فارسی و جیاکەرەوەی هەزار', () {
      expect(FeeTotal.amountOf('ڕەسم: ٢٥٠٠٠'), 25000);
      expect(FeeTotal.amountOf('ڕەسم: ۲۵٬۰۰۰'), 25000);
      expect(FeeTotal.amountOf('ڕەسم: 25,000 دینار'), 25000);
      expect(FeeTotal.amountOf('ڕەسم: 25.000'), 25000); // خاڵ وەک جیاکەرەوەی هەزار
      expect(FeeTotal.amountOf('ڕەسم: 1.5'), 2); // دەیی
    });

    test('«هەزار» و «ملیۆن»', () {
      expect(FeeTotal.amountOf('ڕەسم: ٢٥ هەزار'), 25000);
      expect(FeeTotal.amountOf('ڕەسم: 2 ملیۆن'), 2000000);
      expect(FeeTotal.amountOf('ڕەسم: 25000 هەزار'), 25000); // پێشتر تەواوە
    });

    test('بێ ژمارە → null', () {
      expect(FeeTotal.amountOf('بێ بەرامبەر'), isNull);
      expect(FeeTotal.amountOf(''), isNull);
    });
  });

  group('FeeTotal.of', () {
    test('نموونەی ڕاستەقینەی شاشەکە: 15000 + 25000 + 20000', () {
      final t = FeeTotal.of([
        'پشکنینی چاو: 15000',
        'وەسڵی تەرای: 25000',
        'تێچووی کارتی مۆڵەتی لێخورین: 20000',
      ]);
      expect(t.total, 60000);
      expect(t.counted, 3);
      expect(t.skipped, 0);
      expect(t.isUseful, isTrue);
    });

    test('دۆلار و دێڕی بێ ژمارە دەرەوە دەمێنن و دەژمێردرێن', () {
      final t = FeeTotal.of(['ڕەسم: 10000', 'پشکنین: 5000', 'ڕەسم: 20 \$', 'بێ بەرامبەر', '  ']);
      expect(t.total, 15000);
      expect(t.counted, 2);
      expect(t.skipped, 2);
    });

    test('تەنها یەک بڕ سوودی نییە', () {
      expect(FeeTotal.of(['ڕەسم: 25000']).isUseful, isFalse);
      expect(FeeTotal.of(const []).isUseful, isFalse);
    });
  });

  test('شێوەپێدان', () {
    expect(FeeTotal.format(60000), '60,000');
    expect(FeeTotal.format(1250000), '1,250,000');
    expect(FeeTotal.format(999), '999');
    expect(FeeTotal.format(60000, kurdishDigits: true), '٦٠,٠٠٠');
    expect(FeeTotal.usesEasternDigits(['ڕەسم: ٢٥٠٠٠']), isTrue);
    expect(FeeTotal.usesEasternDigits(['ڕەسم: 25000']), isFalse);
  });
}
