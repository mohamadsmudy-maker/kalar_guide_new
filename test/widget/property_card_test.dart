import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/property.dart';           // ✅ چاککرا
import 'package:kalar_guide_new/widgets/properties/property_card.dart';  // ✅ چاککرا

void main() {
  group('PropertyCard Widget', () {
    testWidgets('دەبێت title پیشان بدات', (tester) async {
      final property = Property(
        propertyType: 'house',
        listingType: 'sale',
        titleKu: 'خانووی تاقیکردنەوە',
        price: 100000000,
        address: 'کەلار',
        ownerName: 'ئەحمەد',
        ownerPhone: '07701234567',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyCard(property: property),
          ),
        ),
      );

      expect(find.text('خانووی تاقیکردنەوە'), findsOneWidget);
    });

    testWidgets('دەبێت typeLabel پیشان بدات', (tester) async {
      final property = Property(
        propertyType: 'house',
        listingType: 'sale',
        titleKu: 'test',
        price: 100000000,
        address: 'test',
        ownerName: 'test',
        ownerPhone: '000',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyCard(property: property),
          ),
        ),
      );

      expect(find.textContaining('خانوو'), findsWidgets);
    });

    testWidgets('onTap دەبێت کار بکات', (tester) async {
      bool tapped = false;
      final property = Property(
        propertyType: 'house',
        listingType: 'sale',
        titleKu: 'test',
        price: 100000000,
        address: 'test',
        ownerName: 'test',
        ownerPhone: '000',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyCard(
              property: property,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PropertyCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('دەبێت formattedPrice پیشان بدات', (tester) async {
      final property = Property(
        propertyType: 'house',
        listingType: 'sale',
        titleKu: 'test',
        price: 100000000,
        address: 'test',
        ownerName: 'test',
        ownerPhone: '000',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyCard(property: property),
          ),
        ),
      );

      expect(find.textContaining('M'), findsWidgets);
    });
  });
}