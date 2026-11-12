import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/admin_department_place_picker.dart';
import 'package:kalar_guide_new/screens/admin/admin_department_service_editor.dart';

void main() {
  group('DepartmentPlaces', () {
    test('شوێنی حکومی بە جۆر، بەش یان ناو دەناسرێتەوە', () {
      expect(DepartmentPlaces.isGovernment({'name': 'x', 'type': 'حکومی'}),
          isTrue);
      expect(
          DepartmentPlaces.isGovernment(
              {'name': 'بەڕێوەبەرایەتی هاتوچۆی گەرمیان', 'type': 'ناحکومی'}),
          isTrue);
      expect(DepartmentPlaces.isGovernment({'name': 'a', 'category': 'فەرمانگە'}),
          isTrue);
      expect(
          DepartmentPlaces.isGovernment(
              {'name': 'چێشتخانەی کەلار', 'category': 'چێشتخانە'}),
          isFalse);
    });

    test('ڕیزی فەرمانگە لە شوێنەوە', () {
      final row = DepartmentPlaces.rowFromPlace({
        'id': 7,
        'name': ' هاتوچۆ ',
        'phone': '',
        'address': 'کەلار',
        'image': null,
      });
      expect(row['place_id'], '7');
      expect(row['name_ku'], 'هاتوچۆ');
      expect(row['phone'], isNull);
      expect(row['address'], 'کەلار');
    });

    test('شوێنی زیادکراو بە place_id یان ناو', () {
      final deps = [
        {'place_id': '7', 'name_ku': 'a'},
        {'place_id': null, 'name_ku': 'دادگا'},
      ];
      expect(DepartmentPlaces.alreadyAdded({'id': 7, 'name': 'z'}, deps), isTrue);
      expect(
          DepartmentPlaces.alreadyAdded({'id': 9, 'name': 'دادگا'}, deps), isTrue);
      expect(DepartmentPlaces.alreadyAdded({'id': 9, 'name': 'نوێ'}, deps),
          isFalse);
    });
  });

  group('service lists', () {
    test('List، دەقی {a,b} و documents ی کۆن', () {
      expect(serviceListOf(['a', ' ', 'b ']), ['a', 'b']);
      expect(serviceListOf('{"a",b}'), ['a', 'b']);
      expect(serviceListOf(null), isEmpty);
      expect(serviceRequirementsOf({'requirements': [], 'documents': ['d']}),
          ['d']);
      expect(serviceRequirementsOf({'requirements': ['r'], 'documents': ['d']}),
          ['r']);
    });
  });

  testWidgets('لیستی هەڵبژاردن: حکومییەکان، هەموو، و زیادکراو', (t) async {
    Map<String, dynamic>? picked;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () async {
              picked = await showModalBottomSheet<Map<String, dynamic>>(
                context: c,
                isScrollControlled: true,
                builder: (_) => DepartmentPlacePickerSheet(
                  existingDepartments: const [
                    {'place_id': '2', 'name_ku': 'دادگای کەلار'}
                  ],
                  loader: () async => [
                    {'id': 1, 'name': 'بەڕێوەبەرایەتی هاتوچۆ', 'type': 'حکومی'},
                    {'id': 2, 'name': 'دادگای کەلار', 'type': 'حکومی'},
                    {'id': 3, 'name': 'چێشتخانە', 'type': 'ناحکومی'},
                  ],
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    expect(find.text('بەڕێوەبەرایەتی هاتوچۆ'), findsOneWidget);
    expect(find.text('چێشتخانە'), findsNothing);
    expect(find.text('زیادکراوە'), findsOneWidget);

    // گەڕان شوێنی ناحکومیش دەدۆزێتەوە بێ گۆڕینی فلتەر
    await t.enterText(find.byType(TextField), 'چێشت');
    await t.pumpAndSettle();
    expect(find.text('چێشتخانە'), findsOneWidget);
    await t.enterText(find.byType(TextField), '');
    await t.pumpAndSettle();
    expect(find.text('چێشتخانە'), findsNothing);

    await t.tap(find.text('هەموو شوێنەکان'));
    await t.pumpAndSettle();
    expect(find.text('چێشتخانە'), findsOneWidget);

    // زیادکراو هەڵنابژێردرێت
    await t.tap(find.text('دادگای کەلار'));
    await t.pumpAndSettle();
    expect(picked, isNull);

    await t.tap(find.text('بەڕێوەبەرایەتی هاتوچۆ'));
    await t.pumpAndSettle();
    expect(picked?['id'], 1);
  });
}
