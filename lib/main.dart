// lib/main.dart
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider, Consumer, Provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

// ═══════════════════════════════════════════════════════════
// ✅ Config
// ═══════════════════════════════════════════════════════════
import 'config/app_colors.dart';
import 'config/constants.dart';
import 'config/env.dart';
import 'config/settings_provider.dart';
import 'config/theme.dart';
import 'config/theme_provider.dart';
import 'config/translations.dart';
import 'l10n/tr.dart';
import 'services/translation_service.dart';

// ═══════════════════════════════════════════════════════════
// ✅ Screens
// ═══════════════════════════════════════════════════════════
import 'screens/about/about_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_fuel_stations.dart';
import 'screens/admin/admin_gallery.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/categories/categories_screen.dart';
import 'screens/categories/category_details.dart';
import 'screens/daily/daily_screen.dart';
import 'screens/emergency/emergency_main_screen.dart';
import 'screens/events/events_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/fuel/fuel_chart_screen.dart';
import 'screens/gallery/gallery_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/stores/stores_screen.dart';
import 'screens/videos/user_videos.dart';

// ═══════════════════════════════════════════════════════════
// ✅ Services & Utils
// ═══════════════════════════════════════════════════════════
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'utils/app_logger.dart';
import 'utils/kurdish_localizations.dart';

// ═══════════════════════════════════════════════════════════
// ✅ Widgets
// ═══════════════════════════════════════════════════════════
import 'widgets/pro_bottom_nav.dart';

// ═══════════════════════════════════════════════════════════
// ⚙️ App config (one place to tweak behaviour)
// ═══════════════════════════════════════════════════════════

const bool _kClearCacheOnStartup = true;
const Duration _kInitTimeout = Duration(seconds: 5);
const Duration _kExitConfirmWindow = Duration(seconds: 2);
const double _kMinFontScale = 0.8;
const double _kMaxFontScale = 1.6;

// ═══════════════════════════════════════════════════════════
// 🔑 Global Keys
// ═══════════════════════════════════════════════════════════
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

// ═══════════════════════════════════════════════════════════
// 🔑 Startup state
// ═══════════════════════════════════════════════════════════
String _supabaseUrl = '';
String _supabaseAnonKey = '';
bool _supabaseReady = false;
bool _bootstrapped = false;
bool _starting = false;
String _bootReason = '';

// ═══════════════════════════════════════════════════════════
// 🔔 Background Message Handler
// ═══════════════════════════════════════════════════════════
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    AppLogger.i('📩 FCM Background: ${message.messageId}');
  } catch (e, stack) {
    AppLogger.e('❌ Background handler error', e);
    AppLogger.d('$stack');
  }
}

// ═══════════════════════════════════════════════════════════
// 🚀 main()
// ═══════════════════════════════════════════════════════════
Future<void> main() async {
  await runZonedGuarded<Future<void>>(
        () async {
      WidgetsFlutterBinding.ensureInitialized();

      try {
        AppLogger.init();
      } catch (e) {
        debugPrint('Logger init failed: $e');
      }

      _installErrorHandlers();
      _configureSystemUi();

      await _start();
    },
        (error, stack) {
      AppLogger.e('🔥 Uncaught zone error', error);
      AppLogger.d('$stack');
    },
  );
}

void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.e(
      '🔥 FlutterError: ${details.exceptionAsString()}',
      details.exception,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('🔥 Platform error', error);
    AppLogger.d('$stack');
    return true;
  };

  ErrorWidget.builder = (details) {
    if (!kReleaseMode) return ErrorWidget(details.exception);
    return const Material(
      color: Colors.transparent,
      child: Center(
        child: Icon(Icons.error_outline_rounded, color: Colors.grey, size: 32),
      ),
    );
  };
}

void _configureSystemUi() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

Future<void> _start() async {
  if (_starting) return;
  _starting = true;
  try {
    _bootReason = '';
    if (!_bootstrapped) {
      await _bootstrap();
      _bootstrapped = true;
    } else {
      await _loadEnv();
      await _initSupabase();
      await _initSession();
    }
  } catch (e, stack) {
    AppLogger.e('🔥 Startup failed', e);
    AppLogger.d('$stack');
    _bootReason = '$e';
  } finally {
    _starting = false;
  }

  if (!_supabaseReady) {
    runApp(_BootErrorApp(onRetry: _start, reason: _bootReason));
    return;
  }

  // ✅ ئاگادارکردنەوە و تۆکنی push دوای دەرکەوتنی ئەپ — نەک پێشی
  // (پێشتر تا ١٠ چرکە زیاتر شاشەی سپلاش دەمایەوە لە ئینتەرنێتی خراپدا)
  unawaited(_initPushLate());

  runApp(
    ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const KalarGuideApp(),
      ),
    ),
  );
}

Future<void> _bootstrap() async {
  if (_kClearCacheOnStartup) {
    try {
      await CacheService.clear();
      AppLogger.i('🗑️ Cache cleared on startup');
    } catch (e) {
      AppLogger.w('⚠️ Cache clear failed: $e');
    }
  }

  await _loadEnv();

  await Future.wait<void>([
    _initDateFormatting(),
    _initConstants(),
    _initSupabase(),
    _initFirebase(),
  ]);

  await _initSession();
}

bool _pushInitDone = false;

Future<void> _initPushLate() async {
  if (_pushInitDone) return;
  _pushInitDone = true;
  await _initNotifications();
  await _refreshPushToken();
}

Future<void> _loadEnv() async {
  try {
    _supabaseUrl = AppEnv.supabaseUrl;
    _supabaseAnonKey = AppEnv.supabaseAnonKey;

    if (kDebugMode) {
      debugPrint('🔑 URL: ${_supabaseUrl.isEmpty ? "❌ EMPTY" : "✅ OK"}');
      debugPrint('🔑 KEY: ${_supabaseAnonKey.isEmpty ? "❌ EMPTY" : "✅ OK"}');
    }

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      _bootReason = 'Supabase keys are empty — build with --dart-define';
      AppLogger.e('❌ $_bootReason');
    }
  } catch (e) {
    _bootReason = 'Config load failed: $e';
    debugPrint('❌ $_bootReason');
  }
}

Future<void> _initDateFormatting() async {
  try {
    await Future.wait([
      initializeDateFormatting('ku', null),
      initializeDateFormatting('ar', null),
      initializeDateFormatting('en', null),
    ]);
    AppLogger.i('✅ DateFormatting initialized');
  } catch (e) {
    AppLogger.w('⚠️ DateFormatting init failed: $e');
  }
}

Future<void> _initConstants() async {
  try {
    await AppConstants.init();
  } catch (e) {
    AppLogger.w('⚠️ AppConstants failed: $e');
  }
}

Future<void> _initSupabase() async {
  if (_supabaseReady) return;

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    AppLogger.e('❌ Supabase keys empty — cannot start');
    return;
  }

  try {
    // ✅ چارەسەرکرا: anonKey گۆڕدرا بۆ publishableKey (بۆ وەشانی نوێی Supabase)
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
    );
    _supabaseReady = true;
    unawaited(TranslationService.loadDiskCache());
    AppLogger.i('✅ Supabase initialized');
  } catch (e) {
    _bootReason = 'Supabase init failed: $e';
    AppLogger.e('❌ $_bootReason', e);
  }
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp().timeout(_kInitTimeout);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    AppLogger.i('✅ Firebase initialized');
  } catch (e) {
    AppLogger.w('⚠️ Firebase init failed: $e');
  }
}

Future<void> _initNotifications() async {
  try {
    if (Firebase.apps.isEmpty) return;
    await NotificationService.initialize().timeout(_kInitTimeout);
    AppLogger.i('✅ Notification Service ready');
  } catch (e) {
    AppLogger.e('❌ Notification init failed', e);
  }
}

Future<void> _refreshPushToken() async {
  try {
    if (Firebase.apps.isEmpty || !AuthSessionManager.isLoggedIn) return;
    await NotificationService.refreshToken().timeout(_kInitTimeout);
  } catch (e) {
    AppLogger.w('⚠️ Push token refresh failed: $e');
  }
}

Future<void> _initSession() async {
  if (!_supabaseReady) return;
  try {
    if (Supabase.instance.client.auth.currentUser == null) {
      try {
        await Supabase.instance.client.auth
            .signInAnonymously()
            .timeout(_kInitTimeout);
        AppLogger.i('✅ Supabase Anonymous Auth initialized');
      } catch (e) {
        AppLogger.w('⚠️ Anonymous Auth failed: $e');
      }
    }

    await AuthSessionManager.initSession().timeout(_kInitTimeout);
    AppLogger.i('✅ initSession تەواو');
  } catch (e) {
    AppLogger.w('⚠️ initSession error: $e');
  }
}

// ═══════════════════════════════════════════════════════════
// 🧯 Boot error screen
// ═══════════════════════════════════════════════════════════
class _BootErrorApp extends StatefulWidget {
  final Future<void> Function() onRetry;
  final String reason;

  const _BootErrorApp({required this.onRetry, this.reason = ''});

  @override
  State<_BootErrorApp> createState() => _BootErrorAppState();
}

class _BootErrorAppState extends State<_BootErrorApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    HapticFeedback.mediumImpact();
    setState(() => _retrying = true);
    await widget.onRetry();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: AppLang.direction,
        child: Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.redSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.redAccent,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr('ئەپەکە نەتوانرا دەستپێبکات'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('ڕێکخستنی پەیوەندی بە سێرڤەرەوە نەدۆزرایەوە. تکایە ئینتەرنێتەکەت بپشکنە و دووبارە هەوڵبدەرەوە.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  if (!kReleaseMode && widget.reason.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        tr(widget.reason),
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _retrying ? null : _retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _retrying
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      tr('دووبارە هەوڵبدەرەوە'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 App Widget
// ═══════════════════════════════════════════════════════════
class KalarGuideApp extends StatelessWidget {
  const KalarGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode =
    context.select<ThemeProvider, ThemeMode>((p) => p.themeMode);
    final settingsProvider = context.watch<SettingsProvider>();

    // ✅ چارەسەرکرا: بانگکردنی فەنکشنەکانی theme بە دروستی
    final lightTextTheme = settingsProvider.getLightTextTheme(
      AppTheme.baseTextTheme(),
    );
    final darkTextTheme = settingsProvider.getDarkTextTheme(
      AppTheme.baseTextTheme(),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: settingsProvider.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        KurdishMaterialLocalizationsDelegate(),
        KurdishCupertinoLocalizationsDelegate(),
        KurdishWidgetsLocalizationsDelegate(),
      ],
      supportedLocales: const [
        Locale('ku', 'IQ'),
        Locale('ar', 'AE'),
        Locale('en', 'US'),
      ],
      theme: AppTheme.lightTheme(textTheme: lightTextTheme),
      darkTheme: AppTheme.darkTheme(textTheme: darkTextTheme),
      themeMode: themeMode,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlay =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: MediaQuery(
            // ✅ قەبارەی فۆنتی سیستەم (accessibility) × ڕێکخستنی ناو ئەپ
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                (MediaQuery.textScalerOf(context).scale(1) *
                        settingsProvider.fontScale)
                    .clamp(_kMinFontScale, _kMaxFontScale)
                    .toDouble(),
              ),
            ),
            // ✅ ئاراستە بەپێی زمان: کوردی/عەرەبی ڕاست-بۆ-چەپ، ئینگلیزی چەپ-بۆ-ڕاست
            child: Directionality(
              textDirection: AppLang.direction,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      onGenerateRoute: _onGenerateRoute,
      home: const SplashScreen(),
    );
  }

  static MaterialPageRoute<T> _page<T>(
      RouteSettings settings,
      WidgetBuilder builder,
      ) {
    return MaterialPageRoute<T>(settings: settings, builder: builder);
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/main':
        return _page(settings, (_) => const MainContainerScreen());
      case '/auth':
        return _page(settings, (_) => const AuthScreen());
      case '/settings':
        return _page(settings, (_) => const SettingsScreen());
      case '/about':
        return _page(settings, (_) => const AboutScreen());
      case '/emergency':
        return _page(settings, (_) => const EmergencyScreen());
      case '/events':
        return _page(settings, (_) => const EventsScreen());
      case '/map':
        return _page(settings, (_) => const MapScreen());
      case '/category':
        final catName = settings.arguments as String? ?? '';
        if (catName.isEmpty) {
          return _page(settings, (_) => const CategoriesScreen());
        }
        return _page(
          settings,
              (_) => CategoryDetailsScreen(categoryName: catName),
        );
      case '/fuel':
        if (!AuthSessionManager.isAdmin) return _unauthorizedRoute();
        return _page(settings, (_) => const AdminFuelStationsScreen());
      case '/admin':
        if (!AuthSessionManager.isAdmin) return _unauthorizedRoute();
        return _page(settings, (_) => const AdminDashboardScreen());
      case '/fuel-chart':
        final args = settings.arguments;
        if (args is! Map<String, dynamic>) {
          return _errorRoute('Arguments نەدۆزرایەوە');
        }
        final history = args['history'];
        final fuelType = args['fuelType'];
        if (history is! List || fuelType is! String) {
          return _errorRoute('Arguments ی نادروست');
        }
        return _page(
          settings,
              (_) => FuelChartScreen(
            history: history.cast<Map<String, dynamic>>(),
            fuelType: fuelType,
          ),
        );
      case '/profile':
        return _page(settings, (_) => const ProfileScreen());
      case '/favorites':
        return _page(settings, (_) => const FavoritesScreen());
      case '/videos':
        return _page(settings, (_) => const UserVideosScreen());
      case '/gallery':
        return _page(settings, (_) => const GalleryScreen());
      case '/admin-gallery':
        if (!AuthSessionManager.isAdmin) return _unauthorizedRoute();
        return _page(settings, (_) => const AdminGallery());
      case '/onboarding':
        return _page(
          settings,
              (context) => OnboardingScreen(
            onComplete: () {
              Navigator.pushReplacementNamed(context, '/main');
            },
          ),
        );
      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(tr('هەڵە')),
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(tr(message), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Route<dynamic> _unauthorizedRoute() {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(tr('⛔ دەستڕاگەیشتن ڕەتکرایەوە')),
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(tr('تەنها ئەدمین دەتوانێت ئەم شاشەیە ببینێت')),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🏠 Main Container
// ═══════════════════════════════════════════════════════════
class MainContainerScreen extends StatefulWidget {
  final int initialIndex;

  const MainContainerScreen({super.key, this.initialIndex = 0});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  static const int _tabCount = 5;

  late int _currentIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPress;

  late final List<Widget Function()> _builders;
  final List<Widget?> _cache = List<Widget?>.filled(_tabCount, null);

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _goTo(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _tabCount - 1);

    _builders = [
          () => HomeScreen(onMenuTap: _openDrawer, onSearchTap: () => _goTo(1)),
          () => StoresScreen(onMenuTap: _openDrawer),
          () => CategoriesScreen(onMenuTap: _openDrawer),
          () => FavoritesScreen(onMenuTap: _openDrawer),
          () => DailyScreen(onMenuTap: _openDrawer),
    ];
  }

  Widget _pageAt(int i) {
    final visited = _cache[i] != null || i == _currentIndex;
    if (!visited) return const SizedBox.shrink();
    return _cache[i] ??= _builders[i]();
  }

  void _handleBack() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return;
    }

    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    final now = DateTime.now();
    final last = _lastBackPress;
    if (last != null && now.difference(last) < _kExitConfirmWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;
    HapticFeedback.selectionClick();
    final lang = context.read<SettingsProvider>().languageId;
    final msg = switch (lang) {
      'en' => 'Press back again to exit',
      'ar' => 'اضغط رجوع مرة أخرى للخروج',
      _ => 'بۆ دەرچوون دووبارە دوگمەی گەڕانەوە دابگرە',
    };
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr(msg)),
          duration: _kExitConfirmWindow,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.select<SettingsProvider, String>((s) => s.languageId);

    String t(String key, String fallback) {
      final translated = AppTranslations.t(key, lang);
      return translated == key ? fallback : translated;
    }

    final navItems = [
      ProNavItem(
        label: t('nav_home', 'سەرەکی'),
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      ProNavItem(
        label: t('nav_places', 'شوێنەکان'),
        icon: Icons.location_on_outlined,
        activeIcon: Icons.location_on_rounded,
      ),
      ProNavItem(
        label: t('nav_categories', 'بەشەکان'),
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
      ),
      ProNavItem(
        label: t('nav_favorites', 'دڵخواز'),
        icon: Icons.favorite_border_rounded,
        activeIcon: Icons.favorite_rounded,
      ),
      ProNavItem(
        label: t('nav_daily', 'ڕۆژانە'),
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        drawer: _AppDrawer(lang: lang, isDark: isDark),
        body: IndexedStack(
          index: _currentIndex,
          children: [for (var i = 0; i < _tabCount; i++) _pageAt(i)],
        ),
        bottomNavigationBar: ProBottomNav(
          currentIndex: _currentIndex,
          onTap: _goTo,
          items: navItems,
          enableHaptics: true,
          activeColor: isDark ? AppColors.secondary : AppColors.primary,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📂 Drawer
// ═══════════════════════════════════════════════════════════
class _AppDrawer extends StatelessWidget {
  final String lang;
  final bool isDark;

  const _AppDrawer({required this.lang, required this.isDark});

  Color get _bg => isDark ? AppColors.darkSurface : const Color(0xFFFCFAFC);

  String _t(String key, String fallback) {
    final translated = AppTranslations.t(key, lang);
    return translated == key ? fallback : translated;
  }

  void _go(BuildContext context, {Widget? screen, String? route}) {
    final nav = Navigator.of(context);
    nav.pop();
    if (screen != null) {
      nav.push(MaterialPageRoute(builder: (_) => screen));
    } else if (route != null) {
      nav.pushNamed(route);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    Navigator.of(context).pop(); // close drawer
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                _t('logout', 'چوونەدەرەوە'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            _t('logout_confirm', 'دڵنیایت دەتەوێت لە هەژمارەکەت بچیتە دەرەوە؟'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(
                _t('no', 'نەخێر'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(_t('yes_logout', 'بەڵێ، دەرچوون')),
            ),
          ],
        ),
      ),
    );

    if (ok == true) await AuthSessionManager.clearSession();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.84,
      // ✅ لای ناوەوەی دراوەر خڕ دەبێت (لە RTL و LTR هەردووکیان)
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(
          end: Radius.circular(30),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Container(
          color: _bg,
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: AuthSessionManager.userNotifier,
                builder: (context, userProfile, _) {
                  final isLogged = userProfile != null;
                  final displayName = isLogged
                      ? (userProfile['name']?.toString() ??
                      _t('user', 'بەکارهێنەر'))
                      : _t('welcome_guest', 'میوانی خۆشەویست');
                  final displayPhone = isLogged
                      ? (userProfile['phone']?.toString() ?? '')
                      : _t('app_name', 'ڕێبەری کەلار');

                  final role =
                      userProfile?['role']?.toString().toLowerCase() ??
                          'customer';
                  final isAdmin = role == 'admin';
                  final isVendor =
                      role == 'vendor' || role == 'department' || isAdmin;

                  return Material(
                    color: _bg,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _header(
                          displayName,
                          displayPhone,
                          role,
                          isLogged,
                          onTap: isLogged
                              ? () => _go(context, screen: const ProfileScreen())
                              : null,
                        ),
                        const SizedBox(height: 6),
                        _section(_t('drawer_sec_emergency', 'فریاکەوتن')),
                        _item(
                          context,
                          icon: Icons.emergency_rounded,
                          color: AppColors.red,
                          title: _t('drawer_emergency', 'فریاکەوتن 🚑'),
                          onTap: () =>
                              _go(context, screen: const EmergencyScreen()),
                        ),
                        _item(
                          context,
                          icon: Icons.event_rounded,
                          color: AppColors.secondary,
                          title: _t('drawer_events', 'ڕووداوەکان 📅'),
                          onTap: () =>
                              _go(context, screen: const EventsScreen()),
                        ),
                        const SizedBox(height: 6),
                        _section(_t('drawer_sec_guide', 'ڕێبەر')),
                        _item(
                          context,
                          icon: Icons.map_rounded,
                          color: AppColors.green,
                          title: _t('drawer_map', 'نەخشەی گەڕەکان 🗺️'),
                          onTap: () => _go(context, route: '/map'),
                        ),
                        _item(
                          context,
                          icon: Icons.person_rounded,
                          color: AppColors.purple,
                          title: _t('drawer_profile', 'پرۆفایلم 👤'),
                          onTap: () =>
                              _go(context, screen: const ProfileScreen()),
                        ),
                        _item(
                          context,
                          icon: Icons.video_library_rounded,
                          color: Colors.indigo,
                          title: _t('drawer_videos', 'ڤیدیۆ و ڕێنماییەکان 🎬'),
                          onTap: () =>
                              _go(context, screen: const UserVideosScreen()),
                        ),
                        _item(
                          context,
                          icon: Icons.photo_library_rounded,
                          color: AppColors.orange,
                          title: _t('drawer_gallery', 'گەلەری کەلار 📸'),
                          onTap: () => _go(context, route: '/gallery'),
                        ),
                        if (isVendor) ...[
                          const SizedBox(height: 8),
                          _section(_t('drawer_sec_manage', 'بەڕێوەبردن')),
                          _item(
                            context,
                            icon: Icons.admin_panel_settings_rounded,
                            color: Colors.blueGrey,
                            title: isAdmin
                                ? _t('drawer_admin', 'پانێڵی ئەدمین 👑')
                                : _t('drawer_vendor', 'پانێڵی بەڕێوەبردن 🏪'),
                            onTap: () => _go(
                              context,
                              screen: const AdminDashboardScreen(),
                            ),
                          ),
                          if (isAdmin)
                            _item(
                              context,
                              icon: Icons.photo_library_rounded,
                              color: AppColors.orange,
                              title: _t(
                                  'drawer_admin_gallery', 'بەڕێوەبردنی گەلەری 📸'),
                              onTap: () =>
                                  _go(context, route: '/admin-gallery'),
                            ),
                        ],
                        const Divider(height: 20),
                        _section(_t('drawer_sec_settings', 'ڕێکخستن')),
                        _item(
                          context,
                          icon: Icons.settings_rounded,
                          color: Colors.blueGrey,
                          title: _t('drawer_settings', 'ڕێکخستنەکان ⚙️'),
                          onTap: () => _go(context, route: '/settings'),
                        ),
                        _themeSwitch(context, themeProvider),
                        _item(
                          context,
                          icon: Icons.person_pin_rounded,
                          color: AppColors.secondary,
                          title: _t('drawer_about', 'دەربارەی من 👨‍💻'),
                          onTap: () =>
                              _go(context, screen: const AboutScreen()),
                        ),
                        const Divider(height: 20),
                        if (!isLogged)
                          _item(
                            context,
                            icon: Icons.login_rounded,
                            color: AppColors.green,
                            title: _t('drawer_login',
                                'چوونەژوورەوە / دروستکردنی ئەکاونت'),
                            onTap: () async {
                              final nav = Navigator.of(context);
                              nav.pop();
                              await nav.push(
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(),
                                ),
                              );
                              try {
                                await NotificationService.refreshToken();
                              } catch (e) {
                                AppLogger.w('⚠️ refreshToken: $e');
                              }
                            },
                          )
                        else
                          _item(
                            context,
                            icon: Icons.logout_rounded,
                            color: Colors.redAccent,
                            textColor: Colors.redAccent,
                            title: _t('drawer_logout', 'چوونەدەرەوە لە هەژمار'),
                            onTap: () => _confirmLogout(context),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(
      String name,
      String phone,
      String role,
      bool isLogged, {
        VoidCallback? onTap,
      }) {
    String? roleLabel;
    switch (role) {
      case 'admin':
        roleLabel = _t('role_admin', 'ئەدمین 👑');
        break;
      case 'vendor':
        roleLabel = _t('role_vendor', 'فرۆشیار 🏪');
        break;
      case 'department':
        roleLabel = _t('role_department', 'فەرمانگە 🏛️');
        break;
    }

    final initial = (isLogged && name.trim().isNotEmpty)
        ? name.trim().characters.first.toUpperCase()
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: initial != null
                    ? Text(
                  tr(initial),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                )
                    : const Icon(
                  Icons.person,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        tr(phone),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                    if (roleLabel != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tr(roleLabel),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        tr(title),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white54 : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _item(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        required VoidCallback onTap,
        Color? textColor,
      }) {
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: _bg,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.20 : 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          tr(title),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: textColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
        trailing: Icon(
          rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          size: 20,
          color: isDark ? Colors.white54 : Colors.grey[500],
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }

  Widget _themeSwitch(BuildContext context, ThemeProvider themeProvider) {
    final effectiveIsDark = themeProvider.isDark(context);

    return Material(
      color: _bg,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (effectiveIsDark ? AppColors.orange : AppColors.purple)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            effectiveIsDark
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            color: effectiveIsDark ? AppColors.orange : AppColors.purple,
            size: 20,
          ),
        ),
        title: Text(
          tr(effectiveIsDark
              ? _t('theme_dark', 'تاریک 🌙')
              : _t('theme_light', 'ڕووناک ☀️')),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        trailing: Switch(
          value: effectiveIsDark,
          onChanged: (value) {
            HapticFeedback.selectionClick();
            themeProvider.toggleTheme(value);
          },
          activeThumbColor: AppColors.primary,
        ),
      ),
    );
  }
}
