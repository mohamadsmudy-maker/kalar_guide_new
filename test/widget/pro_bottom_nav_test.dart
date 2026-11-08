import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/widgets/pro_bottom_nav.dart';

void main() {
  const items = [
    ProNavItem(label: 'A', icon: Icons.home_outlined, activeIcon: Icons.home),
    ProNavItem(label: 'B', icon: Icons.map_outlined, activeIcon: Icons.map),
    ProNavItem(label: 'C', icon: Icons.star_outline, activeIcon: Icons.star),
  ];

  Future<List<int>> pump(WidgetTester t, {required VoidCallback onBody}) async {
    final taps = <int>[];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        extendBody: true,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBody,
          child: const SizedBox.expand(),
        ),
        bottomNavigationBar:
            ProBottomNav(currentIndex: 0, onTap: taps.add, items: items),
      ),
    ));
    return taps;
  }

  testWidgets('tapping a tab reports its index', (t) async {
    final taps = await pump(t, onBody: () {});
    await t.tap(find.text('C'));
    await t.pumpAndSettle();
    expect(taps, [2]);
  });

  testWidgets('empty area above the bar does not swallow taps', (t) async {
    var body = 0;
    await pump(t, onBody: () => body++);
    final bar = t.getRect(find.byType(ProBottomNav));
    // above tab C, outside the raised curve of tab A
    await t.tapAt(Offset(bar.right - 20, bar.top + 4));
    expect(body, 1);
  });
}
