import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/admin_price_types.dart';
import 'package:kalar_guide_new/services/currency_service.dart';
import 'package:kalar_guide_new/services/fuel_service.dart';
import 'package:kalar_guide_new/services/price_types.dart';

class FakeStore implements PriceTypesStore {
  List<Map<String, dynamic>> rows;
  List<dynamic> lastOrder = [];
  int restored = 0;
  FakeStore(this.rows);

  @override
  Future<List<Map<String, dynamic>>> fetch(PriceKind kind) async =>
      [for (final r in rows) Map.of(r)];
  @override
  Future<void> insert(Map<String, dynamic> row) async =>
      rows.add({...row, 'id': rows.length + 100});
  @override
  Future<void> update(id, Map<String, dynamic> row) async {
    final i = rows.indexWhere((r) => r['id'] == id);
    rows[i] = {...rows[i], ...row};
  }
  @override
  Future<void> delete(id) async => rows.removeWhere((r) => r['id'] == id);
  @override
  Future<void> saveOrder(List<dynamic> ids) async => lastOrder = ids;
  @override
  Future<void> restoreDefaults(PriceKind kind) async {
    restored++;
    rows = [
      {'id': 1, 'kind': 'fuel', 'key': 'normal', 'name_ku': 'ئاسایی', 'grp': 'fuel', 'color': '#1E88E5', 'emoji': '⛽', 'unit_ku': 'لیتر'},
    ];
  }
}

List<Map<String, dynamic>> sample() => [
      {'id': 1, 'kind': 'fuel', 'key': 'normal', 'name_ku': 'ئاسایی', 'grp': 'fuel', 'color': '#1E88E5', 'emoji': '⛽', 'unit_ku': 'لیتر'},
      {'id': 2, 'kind': 'fuel', 'key': 'super', 'name_ku': 'سوپەر', 'grp': 'fuel', 'color': '#EF4444', 'emoji': '🔥', 'unit_ku': 'لیتر'},
      {'id': 3, 'kind': 'fuel', 'key': 'iraqi_gas', 'name_ku': 'گازی عێراقی', 'grp': 'gas', 'color': '#10B981', 'emoji': '🔵', 'unit_ku': 'بوتڵ'},
    ];

Widget app(FakeStore s, {PriceKind kind = PriceKind.fuel}) => MaterialApp(
      home: AdminPriceTypesScreen(kind: kind, store: s),
    );

void main() {
  setUp(PriceTypes.resetForTest);

  group('PriceTypes', () {
    test('تا داتا نەهاتبێت لیستی ناو ئەپ بەکاردێت', () {
      expect(FuelService.fuelTypes.length, FuelService.defaultFuelTypes.length);
      expect(CurrencyService.currencyTypes.first['key'], 'usd');
    });

    test('ڕیزی داتابەیس دەبێتە هەمان شێوەی لیستی ناو ئەپ', () {
      final fuel = PriceTypes.fromRow({
        'kind': 'fuel', 'key': 'diesel', 'name_ku': 'دیزڵ', 'grp': 'fuel',
        'color': '#111111', 'emoji': '🚛', 'sort_order': 3,
      })!;
      expect(fuel['key'], 'diesel');
      expect(fuel['name_ar'], 'دیزڵ'); // ئەگەر عەرەبی نەبوو کوردی
      expect(fuel['emoji'], '🚛');
      expect(fuel['unit_ku'], 'لیتر');

      final cur = PriceTypes.fromRow({
        'kind': 'currency', 'key': 'sar', 'name_ku': 'ڕیاڵ', 'grp': 'fiat',
        'emoji': '🇸🇦', 'symbol': 'ر.س', 'per': 100,
      })!;
      expect(cur['flag'], '🇸🇦');
      expect(cur['per'], 100);
      expect(PriceTypes.fromRow({'key': '', 'name_ku': 'x'}), isNull);
    });

    test('کلیلی نوێ: بێ دووبارەبوون و بێ پیتی نایاب', () {
      expect(PriceTypes.makeKey('Diesel Plus', 'دیزڵ', {}), 'diesel_plus');
      expect(PriceTypes.makeKey('Super', 'x', {'super'}), 'super_2');
      expect(PriceTypes.makeKey('', 'دیزڵ', {}), startsWith('type_'));
    });

    test('جۆری ناو ئەپ دەگەڕێتەوە بۆ ڕیزی داتابەیس', () {
      final row = PriceTypes.rowFromDefault(
          PriceKind.currency, CurrencyService.defaultCurrencyTypes.first, 1);
      expect(row['kind'], 'currency');
      expect(row['key'], 'usd');
      expect(row['emoji'], '🇺🇸');
      expect(row['per'], 100);
    });
  });

  group('AdminPriceTypesScreen', () {
    testWidgets('لیست، ڕیزکردن بە ڕاکێشان، و سڕینەوە', (t) async {
      final store = FakeStore(sample());
      await t.pumpWidget(app(store));
      await t.pumpAndSettle();
      expect(find.text('ئاسایی'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(3));

      // سێیەم (گاز) بۆ سەرەوە ڕادەکێشین
      final handle = find.byIcon(Icons.drag_handle_rounded).at(2);
      final gesture = await t.startGesture(t.getCenter(handle));
      await t.pump(const Duration(milliseconds: 200));
      await gesture.moveBy(const Offset(0, -300));
      await t.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await t.pumpAndSettle();
      expect(store.lastOrder.first, 3);
      expect(store.lastOrder.length, 3);

      // سڕینەوە
      await t.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'سڕینەوە'));
      await t.pumpAndSettle();
      expect(store.rows.length, 2);
    });

    testWidgets('زیادکردنی جۆری نوێ کلیلی خۆکار و دوایین ڕیز وەردەگرێت', (t) async {
      final store = FakeStore(sample());
      await t.pumpWidget(app(store));
      await t.pumpAndSettle();
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      // ناوی کوردی و ئینگلیزی
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'دیزڵ');
      await t.enterText(fields.at(2), 'Diesel');
      await t.tap(find.widgetWithText(ElevatedButton, 'زیادکردن'));
      await t.pumpAndSettle();
      final added = store.rows.last;
      expect(added['key'], 'diesel');
      expect(added['name_ku'], 'دیزڵ');
      expect(added['sort_order'], 4);
      expect(added['kind'], 'fuel');
    });

    testWidgets('ناوی کوردی بەتاڵ ناگیرێت', (t) async {
      final store = FakeStore(sample());
      await t.pumpWidget(app(store));
      await t.pumpAndSettle();
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'زیادکردن'));
      await t.pumpAndSettle();
      expect(store.rows.length, 3);
      expect(find.text('ناوی کوردی پێویستە'), findsOneWidget);
    });

    testWidgets('لیستی بەتاڵ: گەڕاندنەوەی جۆرە سەرەکییەکان', (t) async {
      final store = FakeStore([]);
      await t.pumpWidget(app(store));
      await t.pumpAndSettle();
      await t.tap(find.text('گەڕاندنەوەی جۆرە سەرەکییەکان'));
      await t.pumpAndSettle();
      expect(store.restored, 1);
      expect(find.text('ئاسایی'), findsOneWidget);
    });
  });
}
