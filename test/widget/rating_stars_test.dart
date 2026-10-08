import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide/widgets/reviews/rating_stars.dart';

void main() {
  group('RatingStars', () {
    testWidgets('دەبێت ٥ ئایکۆن پیشان بدات', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RatingStars(rating: 3.5, size: 20),
          ),
        ),
      );

      expect(find.byType(Icon), findsNWidgets(5));
    });

    testWidgets('showValue: true دەبێت 3.5 پیشان بدات', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RatingStars(rating: 3.5, showValue: true),
          ),
        ),
      );

      expect(find.text('3.5'), findsOneWidget);
    });

    testWidgets('دەبێت totalReviews پیشان بدات', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RatingStars(rating: 4.0, totalReviews: 100),
          ),
        ),
      );

      expect(find.text('(100)'), findsOneWidget);
    });

    testWidgets('rating=5 دەبێت هەموو ئەستێرەکان پڕ بن', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RatingStars(rating: 5.0),
          ),
        ),
      );

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      for (final icon in icons) {
        expect(icon.icon, equals(Icons.star_rounded));
      }
    });

    testWidgets('rating=0 دەبێت هەموو ئەستێرەکان بەتاڵ بن', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RatingStars(rating: 0.0),
          ),
        ),
      );

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      for (final icon in icons) {
        expect(icon.icon, equals(Icons.star_border_rounded));
      }
    });
  });

  group('RatingInput', () {
    testWidgets('کلیککردن دەبێت onChanged بانگ بکات', (tester) async {
      int? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RatingInput(
              value: 3,
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Icon).last);
      expect(changed, 5);
    });

    testWidgets('دەبێت ٥ ئایکۆن پیشان بدات', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RatingInput(
              value: 3,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(Icon), findsNWidgets(5));
    });
  });
}