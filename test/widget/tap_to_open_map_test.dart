import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/widgets/neighborhoods/tap_to_open_map.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('تەپ دوگمە پیشان دەدات، دوگمە نەخشە دەکاتەوە', (t) async {
    var opened = 0;
    await t.pumpWidget(host(Center(
      child: TapToOpenMap(
        color: Colors.green,
        onOpen: () => opened++,
        map: const ColoredBox(color: Colors.blue),
      ),
    )));

    // پێش تەپ: دوگمە نادیارە و کلیکی لێ ناکرێت
    expect(buttonOpacity(t), 0);
    await t.tap(find.byType(TapToOpenMap));
    await t.pumpAndSettle(const Duration(milliseconds: 300));
    expect(buttonOpacity(t), 1);
    expect(opened, 0);

    await t.tap(find.text('کردنەوەی نەخشە'));
    await t.pumpAndSettle(const Duration(milliseconds: 300));
    expect(opened, 1);
    expect(buttonOpacity(t), 0); // دوای کردنەوە دەشاردرێتەوە
  });

  testWidgets('دوگمەکە دوای ماوەیەک خۆی دەشارێتەوە، و تەپی دووەم دەیشارێتەوە',
      (t) async {
    await t.pumpWidget(host(Center(
      child: TapToOpenMap(
        color: Colors.green,
        hideAfter: const Duration(seconds: 2),
        onOpen: () {},
        map: const ColoredBox(color: Colors.blue),
      ),
    )));
    await t.tap(find.byType(TapToOpenMap));
    await t.pump(const Duration(milliseconds: 300));
    expect(buttonOpacity(t), 1);
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(buttonOpacity(t), 0);

    await t.tap(find.byType(TapToOpenMap));
    await t.pumpAndSettle(const Duration(milliseconds: 300));
    expect(buttonOpacity(t), 1);
    // تەپ لە شوێنێکی دەرەوەی دوگمە (گۆشەی نەخشە) دەیشارێتەوە
    final r = t.getTopLeft(find.byType(TapToOpenMap));
    await t.tapAt(r + const Offset(10, 10));
    await t.pumpAndSettle(const Duration(milliseconds: 300));
    expect(buttonOpacity(t), 0);
  });

  testWidgets('ڕاکێشان بەسەر نەخشەدا لاپەڕەکە سکرۆڵ دەکات (نەخشە پەنجە ناگرێت)',
      (t) async {
    final controller = ScrollController();
    await t.pumpWidget(host(ListView(
      controller: controller,
      children: [
        const SizedBox(height: 100),
        TapToOpenMap(
          color: Colors.green,
          onOpen: () {},
          map: const ColoredBox(color: Colors.blue),
        ),
        const SizedBox(height: 2000),
      ],
    )));
    expect(controller.offset, 0);
    // پەنجە لەسەر نەخشەکە دادەنێین و بەرەو سەرەوە ڕایدەکێشین
    await t.drag(find.byType(TapToOpenMap), const Offset(0, -150));
    await t.pumpAndSettle();
    expect(controller.offset, greaterThan(100));
  });
}

/// شەفافیەتی دوگمەی «کردنەوەی نەخشە» (٠ = شاراوە، ١ = دیار)
double buttonOpacity(WidgetTester t) => t
    .widget<AnimatedOpacity>(find.descendant(
        of: find.byType(TapToOpenMap), matching: find.byType(AnimatedOpacity)))
    .opacity;
