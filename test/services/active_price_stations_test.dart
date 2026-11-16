import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/price_types.dart';

void main() {
  test('شوێنی ناچالاک لادەبرێت؛ بێ ستوون = چالاک', () {
    final r = activePriceStations([
      {'id': 1},
      {'id': 2, 'prices_active': false},
      {'id': 3, 'prices_active': true},
    ]);
    expect(r!.map((s) => s['id']), [1, 3]);
  });

  test('هەموویان ناچالاک → null (نرخی گشتی)', () {
    expect(
      activePriceStations([
        {'id': 1, 'prices_active': false},
        {'id': 2, 'prices_active': false},
      ]),
      isNull,
    );
  });

  test('هیچ شوێنێک نییە → لیستی بەتاڵ، نەک نرخی گشتی', () {
    expect(activePriceStations([]), isEmpty);
  });
}
