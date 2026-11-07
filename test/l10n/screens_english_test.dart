// test/l10n/screens_english_test.dart
//
// شاشە سەرەکییەکان بە کوردی، ئینگلیزی و عەرەبی دەکرێنەوە و پشکنین دەکرێت
// کە هیچ دەقێکی کوردی (پیتی ە ێ ۆ ڕ ڵ) لە ڕووکاردا نەماوە.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:kalar_guide_new/screens/about/about_screen.dart';
import 'package:kalar_guide_new/screens/about/instructions_screen.dart';
import 'package:kalar_guide_new/screens/auth/auth_screen.dart';
import 'package:kalar_guide_new/screens/complaints/submit_complaint.dart';
import 'package:kalar_guide_new/screens/departments/departments_screen.dart';
import 'package:kalar_guide_new/screens/emergency/emergency_main_screen.dart';
import 'package:kalar_guide_new/screens/events/events_screen.dart';
import 'package:kalar_guide_new/screens/favorites/favorites_screen.dart';
import 'package:kalar_guide_new/screens/fuel/fuel_calculator_screen.dart';
import 'package:kalar_guide_new/screens/home/home_screen.dart';
import 'package:kalar_guide_new/screens/neighborhoods/neighborhoods_screen.dart';
import 'package:kalar_guide_new/screens/news/all_news_screen.dart';
import 'package:kalar_guide_new/screens/onboarding/onboarding_screen.dart';
import 'package:kalar_guide_new/screens/prayer/adhan_settings_screen.dart';
import 'package:kalar_guide_new/screens/prayer/prayer_weekly_view.dart';
import 'package:kalar_guide_new/screens/profile/profile_screen.dart';
import 'package:kalar_guide_new/screens/weather/weather_screen.dart';
import 'package:kalar_guide_new/config/settings_provider.dart';
import 'package:kalar_guide_new/config/theme_provider.dart';
import 'package:kalar_guide_new/l10n/tr.dart';
import 'package:kalar_guide_new/screens/categories/categories_screen.dart';
import 'package:kalar_guide_new/screens/daily/daily_screen.dart';
import 'package:kalar_guide_new/screens/prayer/prayer_settings_screen.dart';
import 'package:kalar_guide_new/screens/settings/settings_screen.dart';
import 'package:kalar_guide_new/screens/stores/stores_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _kurdish = RegExp(r'[ەێۆڕڵ]');

List<String> _visibleKurdish(WidgetTester tester) {
  final out = <String>{};
  for (final w in tester.widgetList(find.byWidgetPredicate((w) => w is Text || w is RichText))) {
    final text = w is Text ? (w.data ?? w.textSpan?.toPlainText() ?? '') : (w as RichText).text.toPlainText();
    if (_kurdish.hasMatch(text)) out.add(text);
  }
  for (final w in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    if (_kurdish.hasMatch(w.message ?? '')) out.add('tooltip: ${w.message}');
  }
  return out.toList()..sort();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
      ),
    );
  });

  final screens = <String, Widget Function()>{
    'Daily': () => const DailyScreen(),
    'Categories': () => const CategoriesScreen(),
    'Places': () => const StoresScreen(),
    'Settings': () => const SettingsScreen(),
    'Prayer settings': () => const PrayerSettingsScreen(),
    'Home': () => const HomeScreen(),
    'About': () => const AboutScreen(),
    'Instructions': () => const InstructionsScreen(),
    'Profile': () => const ProfileScreen(),
    'Favorites': () => const FavoritesScreen(),
    'Auth': () => const AuthScreen(),
    'Prayer weekly': () => const PrayerWeeklyView(lat: 34.6178, lng: 45.3325),
    'Adhan sounds': () => const AdhanSettingsScreen(),
    'Emergency': () => const EmergencyScreen(),
    'All news': () => const AllNewsScreen(),
    'Onboarding': () => OnboardingScreen(onComplete: () {}),
    'Weather': () => const WeatherScreen(),
    'Events': () => const EventsScreen(),
    'Departments': () => const DepartmentsScreen(),
    'Neighborhoods': () => const NeighborhoodsScreen(),
    'Fuel calculator': () => const FuelCalculatorScreen(),
    'Submit complaint': () => const SubmitComplaintScreen(),
  };

  for (final lang in ['ku', 'en', 'ar']) {
    for (final e in screens.entries) {
      testWidgets('${e.key} [$lang] — هیچ دەقێکی کوردی نییە', (tester) async {
        SharedPreferences.setMockInitialValues({'language_id': lang});
        AppLang.setCode(lang);
        addTearDown(() => AppLang.setCode('ku'));
        // فۆنتی تێست (Ahem) هەموو پیتێک چوارگۆشەیەکی پانە، بۆیە overflow ی
        // ساختە دروست دەکات — ئەو هەڵانە پشتگوێ دەخرێن، هەڵەی تر نا.
        final onError = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.exceptionAsString().contains('overflowed')) return;
          onError?.call(d);
        };
        addTearDown(() => FlutterError.onError = onError);
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 2.6;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(ProviderScope(child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            home: Directionality(textDirection: AppLang.direction, child: e.value()),
          ),
        )));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        final left = _visibleKurdish(tester);
        // داتای ناو داتابەیس (ناوی شوێن...) لێرە نییە، چونکە Supabase ی تێست بەتاڵە
        if (lang != 'ku') expect(left, isEmpty, reason: left.join('\n'));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 15)); // تایمەری timeout ی Supabase
      });
    }
  }
}
