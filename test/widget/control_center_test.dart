// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/admin_control_center.dart';
import 'package:kalar_guide_new/services/admin_stats.dart';
import 'package:kalar_guide_new/services/app_control.dart';
import 'package:kalar_guide_new/widgets/app_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

AdminStats sample() => AdminStats.fromJson({
      'days': 30,
      'totals': {'places': 141, 'departments': 3, 'news': 7, 'events': 2, 'users': 30, 'complaints': 17},
      'complaints': {
        'now': 17, 'prev': 10, 'pending': 5, 'resolved': 9,
        'daily': [
          for (var i = 1; i <= 7; i++) {'d': '2026-11-0$i', 'n': i % 3}
        ],
        'by_status': {'pending': 5, 'completed': 9, 'rejected': 3},
        'top_neighborhoods': [
          {'name': 'ئازادی', 'n': 8}
        ],
      },
      'users': {'now': 4, 'prev': 4, 'online': 3, 'daily': [], 'by_role': {'customer': 20, 'vendor': 3}},
      'places': {
        'now': 2, 'prev': 0,
        'by_category': [
          {'name': 'تەندروستی', 'n': 12}
        ],
      },
      'search': {
        'now': 20, 'prev': 10,
        'top': [
          {'name': 'نوێژ', 'n': 6}
        ],
        'no_results': [
          {'name': 'کباب', 'n': 3}
        ],
      },
    });

Widget host(Widget w) => MaterialApp(home: w);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ئامار: KPI، چارت، و گەڕانی بێ ئەنجام', (t) async {
    t.view.physicalSize = const Size(900, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    int? askedDays;
    await t.pumpWidget(host(AdminControlCenterScreen(
      statsLoader: (d) async {
        askedDays = d;
        return sample();
      },
      saver: (k, v) async => true,
      healthLoader: () async => {'price_types': true},
    )));
    await t.pumpAndSettle();
    expect(askedDays, 30);
    expect(find.text('سکاڵای نوێ'), findsWidgets);
    expect(find.textContaining('کباب'), findsWidgets); // گەڕانی بێ ئەنجام
    expect(find.text('ئازادی'), findsWidgets);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsWidgets); // سکاڵا 10 → 17

    // گۆڕینی ماوە
    await t.tap(find.textContaining('٧').first); // ٧ ڕۆژ (ژمارەی کوردی)
    await t.pumpAndSettle();
    expect(askedDays, 7);
  });

  testWidgets('ئەگەر RPC نەبوو: هەڵە و ڕێنمایی مایگرەیشن', (t) async {
    await t.pumpWidget(host(AdminControlCenterScreen(
      statsLoader: (d) async => throw Exception('function does not exist'),
      saver: (k, v) async => true,
      healthLoader: () async => {},
    )));
    await t.pumpAndSettle();
    expect(find.text('ئامار نەهات'), findsOneWidget);
    expect(find.textContaining('20261119_admin_stats.sql'), findsOneWidget);
  });

  testWidgets('کۆنترۆڵ: حالەتی چاککردن بە کلیل و ناوەڕۆکی ڕاست پاشەکەوت دەکات', (t) async {
    t.view.physicalSize = const Size(900, 3600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final saved = <String, Object>{};
    await t.pumpWidget(host(AdminControlCenterScreen(
      statsLoader: (d) async => sample(),
      saver: (k, v) async {
        saved[k] = v;
        return true;
      },
      healthLoader: () async => {},
    )));
    await t.pumpAndSettle();
    await t.tap(find.text('کۆنترۆڵ'));
    await t.pumpAndSettle();

    await t.tap(find.widgetWithText(SwitchListTile, 'چالاککردن'));
    await t.pump();
    await t.enterText(find.widgetWithText(TextField, 'پەیام (ئارەزوومەندانە)').first, 'سبەینێ دێینەوە');
    await t.tap(find.widgetWithText(FilledButton, 'پاشەکەوتکردن').first);
    await t.pumpAndSettle();
    expect(saved['maintenance'], {'enabled': true, 'message': 'سبەینێ دێینەوە'});
  });

  testWidgets('سیستەم: فایلی مایگرەیشنی ماو پیشان دەدرێت', (t) async {
    await t.pumpWidget(host(AdminControlCenterScreen(
      statsLoader: (d) async => sample(),
      saver: (k, v) async => true,
      healthLoader: () async => {'price_types': false, 'app_settings': true},
    )));
    await t.pumpAndSettle();
    await t.tap(find.text('سیستەم'));
    await t.pumpAndSettle();
    expect(find.textContaining('20261118_price_types.sql'), findsWidgets);
    expect(find.text('app_settings'), findsOneWidget);
  });

  group('AppGate', () {
    Widget gate(AppControlState s, {String version = '1.1.0'}) => MaterialApp(
          home: AppGate(
            currentVersion: version,
            controlOverride: ValueNotifier(s),
            child: const Scaffold(body: Text('ناوەڕۆکی ئەپ')),
          ),
        );

    testWidgets('کراوە: هیچ بلۆکێک نییە', (t) async {
      await t.pumpWidget(gate(const AppControlState()));
      expect(find.text('ئەپەکە لە چاککردندایە'), findsNothing);
      expect(find.text('نوێکردنەوە پێویستە'), findsNothing);
    });

    testWidgets('حالەتی چاککردن بلۆک دەکات و پەیامی ئەدمین پیشان دەدات', (t) async {
      await t.pumpWidget(gate(const AppControlState(maintenance: true, maintenanceMessage: 'سبەینێ')));
      expect(find.text('ئەپەکە لە چاککردندایە'), findsOneWidget);
      expect(find.text('سبەینێ'), findsOneWidget);
    });

    testWidgets('وەشانی کۆن بلۆک دەکات، وەشانی ڕێک نا', (t) async {
      await t.pumpWidget(gate(const AppControlState(minVersion: '1.2.0'), version: '1.1.0'));
      expect(find.text('نوێکردنەوە پێویستە'), findsOneWidget);
      await t.pumpWidget(gate(const AppControlState(minVersion: '1.2.0'), version: '1.2.0'));
      expect(find.text('نوێکردنەوە پێویستە'), findsNothing);
    });
  });
}
