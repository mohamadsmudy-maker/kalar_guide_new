import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/about/about_screen.dart';

void main() {
  testWidgets('سەرپەڕی دەربارە: وێنە و ناو لە ناوەڕاستدان', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pump(const Duration(seconds: 2));

    final screenCenter = tester.getSize(find.byType(Scaffold)).width / 2;
    final avatar = tester.getCenter(find.byType(CircleAvatar).first).dx;
    final name = tester.getCenter(find.text('محمد احمد محمد').first).dx;
    expect(avatar, closeTo(screenCenter, 1));
    expect(name, closeTo(screenCenter, 1));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
