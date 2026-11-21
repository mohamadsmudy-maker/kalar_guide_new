import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/admin_place_claims.dart';
import 'package:kalar_guide_new/screens/stores/claim_place_sheet.dart';
import 'package:kalar_guide_new/services/place_claim_service.dart';

void main() {
  testWidgets('owner sends a claim', (t) async {
    final sent = <String>[];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => ClaimPlaceSheet(
            storeId: 5,
            storeName: 'Shop',
            sender: (id, note) async {
              sent.add('$id:$note');
              return 'ok';
            },
          ),
        ),
      ),
    ));
    await t.enterText(find.byType(TextField), 'I own it');
    await t.tap(find.byKey(const ValueKey('claim-send')));
    await t.pump();
    expect(sent, ['5:I own it']);
  });

  testWidgets('admin approves a claim', (t) async {
    final reviewed = <String>[];
    await t.pumpWidget(MaterialApp(
      home: AdminPlaceClaimsScreen(
        loader: () async => const [
          PlaceClaim(id: 1, storeId: '5', storeName: 'Shop', userName: 'Ali', userPhone: '0750'),
        ],
        reviewer: (id, ok) async {
          reviewed.add('$id:$ok');
          return true;
        },
      ),
    ));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('approve-1')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'پەسەندکردن').last);
    await t.pumpAndSettle();
    expect(reviewed, ['1:true']);
    expect(find.byKey(const ValueKey('claim-1')), findsNothing);
  });
}
