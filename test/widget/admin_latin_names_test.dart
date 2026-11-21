import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/admin_latin_names.dart';
import 'package:kalar_guide_new/services/place_names_service.dart';

void main() {
  test('isLatinName', () {
    expect(PlaceNamesService.isLatinName('Kalar Hospital'), isTrue);
    expect(PlaceNamesService.isLatinName('نەخۆشخانەی کەلار'), isFalse);
    expect(PlaceNamesService.isLatinName('Kalar مارکێت'), isFalse);
    expect(PlaceNamesService.isLatinName('123'), isFalse);
  });

  testWidgets('suggest then save renames selected places', (t) async {
    final renamed = <String>[];
    await t.pumpWidget(MaterialApp(
      home: AdminLatinNamesScreen(
        loader: () async => [
          {'id': 1, 'name': 'Kalar Hospital', 'category': 'x'},
          {'id': 2, 'name': 'Star Market', 'category': 'y'},
        ],
        suggest: (names) async => [for (final n in names) n == 'Kalar Hospital' ? 'نەخۆشخانەی کەلار' : ''],
        rename: (id, old, name) async => renamed.add('$id:$old>$name'),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Kalar Hospital'), findsOneWidget);
    expect(find.text('Star Market'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('suggest')));
    await t.pumpAndSettle();
    expect(find.text('نەخۆشخانەی کەلار'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('save')));
    await t.pumpAndSettle();
    expect(renamed, ['1:Kalar Hospital>نەخۆشخانەی کەلار']);
    expect(find.text('Kalar Hospital'), findsNothing);
    expect(find.text('Star Market'), findsOneWidget);
  });
}
