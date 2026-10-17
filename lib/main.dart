// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider, Consumer, Provider;
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
// ✅ Config
// ═══════════════════════════════════════════════════════════
import 'config/constants.dart';
import 'config/settings_provider.dart';
import 'config/theme.dart';
import 'config/theme_provider.dart';
import 'config/translations.dart';

// ═══════════════════════════════════════════════════════════
// ✅ Screens
// ═══════════════════════════════════════════════════════════
import 'screens/about/about_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_fuel_stations.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/categories/categories_screen.dart';
import 'screens/categories/category_details.dart';
import 'screens/daily/daily_screen.dart';
import 'screens/emergency/emergency_main_screen.dart';
import 'screens/events/events_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/fuel/fuel_chart_screen.dart';
import 'screens/home/home_screen.dart';
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
// 🔑 Global Keys
// ═══════════════════════════════════════════════════════════
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

// ═══════════════════════════════════════════════════════════
// 🔑 Supabase Values
// ═══════════════════════════════════════════════════════════
String _supabaseUrl = '';
String _supabaseAnonKey = '';

// ═══════════════════════════════════════════════════════════
// 🔔 Background Message Handler
// ═══════════════════════════════════════════════════════════
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    AppLogger.i('📩 FCM Background: ${message.messageId}');
  } catch (e) {
    AppLogger.e('❌ Background handler error', e);
  }
}

// ═══════════════════════════════════════════════════════════
// 🚀 main()
// ═══════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    AppLogger.init();
  } catch (e) {
    debugPrint('Logger init failed: $e');
  }

  // ⭐ پاککردنەوەی کاش
  try {
    await CacheService.clear();
    AppLogger.i('🗑️ Cache cleared on startup');
  } catch (e) {
    AppLogger.w('⚠️ Cache clear failed: $e');
  }

  // ⭐ خوێندنەوەی کلیلەکان
  try {
    _supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
    _supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      try {
        await dotenv.load(fileName: '.env');
        _supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
        _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
        AppLogger.i('📄 .env loaded');
      } catch (e) {
        AppLogger.w('⚠️ .env load failed: $e');
      }
    }

    debugPrint('🔑 URL: ${_supabaseUrl.isEmpty ? "❌ EMPTY" : "✅ OK"}');
    debugPrint('🔑 KEY: ${_supabaseAnonKey.isEmpty ? "❌ EMPTY" : "✅ OK"}');
  } catch (e) {
    debugPrint('❌ Config load failed: $e');
  }

  try {
    await AppConstants.init();
  } catch (e) {
    AppLogger.w('⚠️ AppConstants failed: $e');
  }

  await _initSupabase();
  await _initFirebase();
  await _initNotifications();
  await _initSession();

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

Future<void> _initSupabase() async {
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    AppLogger.e('❌ Supabase keys empty — skipping');
    return;
  }

  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
    AppLogger.i('✅ Supabase initialized');
    debugPrint('✅ Supabase initialized');
  } catch (e) {
    AppLogger.e('❌ Supabase init failed', e);
  }
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
    AppLogger.i('✅ Firebase initialized');
  } catch (e) {
    AppLogger.w('⚠️ Firebase init failed: $e');
  }
}

Future<void> _initNotifications() async {
  try {
    if (Firebase.apps.isEmpty) return;
    await NotificationService.initialize()
        .timeout(const Duration(seconds: 5));
    AppLogger.i('✅ Notification Service ready');

    if (AuthSessionManager.isLoggedIn) {
      await NotificationService.refreshToken();
    }
  } catch (e) {
    AppLogger.e('❌ Notification init failed', e);
  }
}

Future<void> _initSession() async {
  try {
    await AuthSessionManager.initSession()
        .timeout(const Duration(seconds: 5));
    AppLogger.i('✅ initSession تەواو');
  } catch (e) {
    AppLogger.w('⚠️ initSession error: $e');
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 App Widget
// ═══════════════════════════════════════════════════════════
class KalarGuideApp extends StatelessWidget {
  const KalarGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

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
      theme: AppTheme.lightTheme.copyWith(
        textTheme: settingsProvider.getLightTextTheme(
          AppTheme.lightTheme.textTheme,
        ),
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        textTheme: settingsProvider.getDarkTextTheme(
          AppTheme.darkTheme.textTheme,
        ),
      ),
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settingsProvider.fontScale),
          ),
          child: child!,
        );
      },
      onGenerateRoute: _onGenerateRoute,
      home: const SplashScreen(),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/main':
        return MaterialPageRoute(
            builder: (_) => const MainContainerScreen());
      case '/auth':
        return MaterialPageRoute(builder: (_) => const AuthScreen());
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case '/about':
        return MaterialPageRoute(builder: (_) => const AboutScreen());
      case '/emergency':
        return MaterialPageRoute(builder: (_) => const EmergencyScreen());
      case '/events':
        return MaterialPageRoute(builder: (_) => const EventsScreen());
      case '/category':
        final catName = settings.arguments as String? ?? '';
        if (catName.isEmpty) {
          return MaterialPageRoute(
              builder: (_) => const CategoriesScreen());
        }
        return MaterialPageRoute(
          builder: (_) => CategoryDetailsScreen(categoryName: catName),
        );
      case '/fuel':
        if (!AuthSessionManager.isAdmin) return _unauthorizedRoute();
        return MaterialPageRoute(
            builder: (_) => const AdminFuelStationsScreen());
      case '/admin':
        if (!AuthSessionManager.isAdmin) return _unauthorizedRoute();
        return MaterialPageRoute(
            builder: (_) => const AdminDashboardScreen());
      case '/fuel-chart':
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) return _errorRoute('Arguments نەدۆزرایەوە');
        final history = args['history'];
        final fuelType = args['fuelType'];
        if (history is! List || fuelType is! String) {
          return _errorRoute('Arguments ی نادروست');
        }
        return MaterialPageRoute(
          builder: (_) => FuelChartScreen(
            history: history.cast<Map<String, dynamic>>(),
            fuelType: fuelType,
          ),
        );
      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case '/favorites':
        return MaterialPageRoute(builder: (_) => const FavoritesScreen());
      case '/videos':
        return MaterialPageRoute(builder: (_) => const UserVideosScreen());
      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('هەڵە'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Route<dynamic> _unauthorizedRoute() {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('⛔ دەستڕاگەیشتن ڕەتکرایەوە'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('تەنها ئەدمین دەتوانێت ئەم شاشەیە ببینێت'),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🏠 Main Container
// ═══════════════════════════════════════════════════════════
class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  List<Widget> get _pages => [
    HomeScreen(onMenuTap: _openDrawer),
    StoresScreen(onMenuTap: _openDrawer),
    CategoriesScreen(onMenuTap: _openDrawer),
    FavoritesScreen(onMenuTap: _openDrawer),
    DailyScreen(onMenuTap: _openDrawer),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final lang = settings.languageId;

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
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        drawer: _AppDrawer(lang: lang, isDark: isDark),
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: ProBottomNav(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: navItems,
          enableHaptics: true,
          activeColor:
          isDark ? const Color(0xFF8B5CF6) : const Color(0xFF1E88E5),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📂 Drawer — کورتکراوە
// ═══════════════════════════════════════════════════════════
class _AppDrawer extends StatelessWidget {
  final String lang;
  final bool isDark;

  const _AppDrawer({required this.lang, required this.isDark});

  String _t(String key, String fallback) {
    final translated = AppTranslations.t(key, lang);
    return translated == key ? fallback : translated;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.84,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(30)),
      ),
      child: SafeArea(
        child: Container(
          color: isDark ? const Color(0xFF121218) : const Color(0xFFFCFAFC),
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: AuthSessionManager.userNotifier,
                builder: (context, userProfile, _) {
                  final isLogged = userProfile != null;
                  final displayName = isLogged
                      ? (userProfile['name']?.toString() ?? 'بەکارهێنەر')
                      : _t('welcome_guest', 'میوانی خۆشەویست');
                  final displayPhone = isLogged
                      ? (userProfile['phone']?.toString() ?? '')
                      : _t('app_name', 'ڕێبەری کەلار');

                  final role =
                      userProfile?['role']?.toString().toLowerCase() ??
                          'customer';
                  final isAdmin = role == 'admin';
                  final isVendor = role == 'vendor' ||
                      role == 'department' ||
                      isAdmin;

                  return Material(
                    color: isDark
                        ? const Color(0xFF121218)
                        : const Color(0xFFFCFAFC),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        UserAccountsDrawerHeader(
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E88E5),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                          currentAccountPicture: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person,
                                size: 36, color: Color(0xFF1E88E5)),
                          ),
                          accountName: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          accountEmail: Text(
                            displayPhone,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _section('فریاکەوتن'),
                        _item(
                          context,
                          icon: Icons.emergency_rounded,
                          color: Colors.red,
                          title: 'فریاکەوتن 🚑',
                          onTap: () =>
                              _push(context, const EmergencyScreen()),
                        ),
                        _item(
                          context,
                          icon: Icons.event_rounded,
                          color: const Color(0xFF6C5CE7),
                          title: 'ڕووداوەکان 📅',
                          onTap: () => _push(context, const EventsScreen()),
                        ),
                        const SizedBox(height: 6),
                        _section('ڕێبەر'),
                        _item(
                          context,
                          icon: Icons.person_rounded,
                          color: Colors.purple,
                          title: 'پرۆفایلم 👤',
                          onTap: () =>
                              _push(context, const ProfileScreen()),
                        ),
                        _item(
                          context,
                          icon: Icons.video_library_rounded,
                          color: Colors.indigo,
                          title: 'ڤیدیۆ و ڕێنماییەکان 🎬',
                          onTap: () =>
                              _push(context, const UserVideosScreen()),
                        ),
                        if (isVendor) ...[
                          const SizedBox(height: 8),
                          _section('بەڕێوەبردن'),
                          _item(
                            context,
                            icon: Icons.admin_panel_settings_rounded,
                            color: Colors.blueGrey,
                            title: isAdmin
                                ? 'پانێڵی ئەدمین 👑'
                                : 'پانێڵی بەڕێوەبردن 🏪',
                            onTap: () => _push(
                                context, const AdminDashboardScreen()),
                          ),
                        ],
                        const Divider(height: 20),
                        _section('ڕێکخستن'),
                        _item(
                          context,
                          icon: Icons.settings_rounded,
                          color: Colors.blueGrey,
                          title: 'ڕێکخستنەکان ⚙️',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/settings');
                          },
                        ),
                        _themeSwitch(context, themeProvider),
                        _item(
                          context,
                          icon: Icons.person_pin_rounded,
                          color: const Color(0xFF6C5CE7),
                          title: 'دەربارەی من 👨‍💻',
                          onTap: () => _push(context, const AboutScreen()),
                        ),
                        const Divider(height: 20),
                        if (!isLogged)
                          _item(
                            context,
                            icon: Icons.login_rounded,
                            color: Colors.green,
                            title: 'چوونەژوورەوە / دروستکردنی ئەکاونت',
                            onTap: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(),
                                ),
                              );
                              await NotificationService.refreshToken();
                            },
                          )
                        else
                          _item(
                            context,
                            icon: Icons.logout_rounded,
                            color: Colors.redAccent,
                            textColor: Colors.redAccent,
                            title: 'چوونەدەرەوە لە هەژمار',
                            onTap: () async {
                              Navigator.pop(context);
                              await AuthSessionManager.clearSession();
                            },
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

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        title,
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
    return Material(
      color: isDark ? const Color(0xFF121218) : const Color(0xFFFCFAFC),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: textColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
        trailing: Icon(
          Icons.chevron_left_rounded,
          size: 20,
          color: isDark ? Colors.white54 : Colors.grey[500],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _themeSwitch(BuildContext context, ThemeProvider themeProvider) {
    final effectiveIsDark = themeProvider.isDark(context);

    return Material(
      color: isDark ? const Color(0xFF121218) : const Color(0xFFFCFAFC),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (effectiveIsDark ? Colors.orange : Colors.purple)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            effectiveIsDark
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            color: effectiveIsDark ? Colors.orange : Colors.purple,
            size: 20,
          ),
        ),
        title: Text(
          effectiveIsDark ? 'تاریک 🌙' : 'ڕووناک ☀️',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        trailing: Switch(
          value: effectiveIsDark,
          onChanged: (value) => themeProvider.toggleTheme(value),
          activeThumbColor: const Color(0xFF1E88E5),
        ),
      ),
    );
  }
}