import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
// ✅ Config Imports
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
import 'screens/emergency/emergency_screen.dart';
import 'screens/events/events_screen.dart';                    // ✅ دروستکرا
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

  AppLogger.init();

  await _loadEnv();
  await AppConstants.init();
  await _initSupabase();
  await _initFirebase();
  await _initNotifications();

  Future.microtask(() async {
    await AuthSessionManager.initSession();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const KalarGuideApp(),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// 📦 Initialization Helpers
// ═══════════════════════════════════════════════════════════
String _readEnv(String key) {
  final envValue = dotenv.env[key] ?? '';
  if (envValue.isNotEmpty) return envValue;

  switch (key) {
    case 'SUPABASE_URL':
      return const String.fromEnvironment('SUPABASE_URL');
    case 'SUPABASE_ANON_KEY':
      return const String.fromEnvironment('SUPABASE_ANON_KEY');
    case 'GEMINI_API_KEY':
      return const String.fromEnvironment('GEMINI_API_KEY');
    case 'GOOGLE_MAPS_API_KEY':
      return const String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    case 'PASSWORD_SALT':
      return const String.fromEnvironment(
        'PASSWORD_SALT',
        defaultValue: 'kalar_guide_2024_secure_salt_v1',
      );
    default:
      return '';
  }
}

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
    AppLogger.i('✅ .env بارکرا');
  } catch (e) {
    AppLogger.w('⚠️ .env نەدۆزرایەوە — --dart-define بەکاردهێت');

    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw StateError(
        '❌ Missing environment config. '
            'Either provide .env (debug) or --dart-define (release).',
      );
    }
    AppLogger.i('✅ --dart-define بەکاردهێت');
  }
}

Future<void> _initSupabase() async {
  final url = _readEnv('SUPABASE_URL');
  final key = _readEnv('SUPABASE_ANON_KEY');

  if (url.isEmpty || key.isEmpty) {
    throw StateError('❌ SUPABASE_URL / SUPABASE_ANON_KEY missing');
  }

  try {
    await Supabase.initialize(url: url, anonKey: key);
    AppLogger.i('✅ Supabase initialized');
  } catch (e) {
    AppLogger.e('❌ Supabase init failed', e);
    rethrow;
  }
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
    AppLogger.i('✅ Firebase initialized');
  } catch (e) {
    AppLogger.e('❌ Firebase init failed', e);
  }
}

Future<void> _initNotifications() async {
  try {
    if (Firebase.apps.isEmpty) {
      AppLogger.w('⚠️ Firebase not initialized — skipping notifications');
      return;
    }

    await NotificationService.initialize();
    AppLogger.i('✅ Notification Service ready');

    if (AuthSessionManager.currentUser != null) {
      await NotificationService.refreshToken();
    }
  } catch (e) {
    AppLogger.e('❌ Notification init failed', e);
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

  // ═══════════════════════════════════════════════════════════
  // 🗺️ Route Generation
  // ═══════════════════════════════════════════════════════════
  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/main':
        return MaterialPageRoute(
          builder: (_) => const MainContainerScreen(),
        );

      case '/auth':
        return MaterialPageRoute(builder: (_) => const AuthScreen());

      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case '/about':
        return MaterialPageRoute(builder: (_) => const AboutScreen());

      case '/emergency':
        return MaterialPageRoute(
          builder: (_) => const EmergencyScreen(),
        );

      case '/events':                                    // ✅ نوێ
        return MaterialPageRoute(
          builder: (_) => const EventsScreen(),
        );

      case '/category':
        final catName = settings.arguments as String? ?? '';
        if (catName.isEmpty) {
          return MaterialPageRoute(
            builder: (_) => const CategoriesScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => CategoryDetailsScreen(categoryName: catName),
        );

      case '/fuel':
        return MaterialPageRoute(
          builder: (_) => const AdminFuelStationsScreen(),
        );

      case '/fuel-chart':
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) {
          return MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('هەڵە')),
              body: const Center(child: Text('Arguments نەدۆزرایەوە')),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => FuelChartScreen(
            history: args['history'] as List<Map<String, dynamic>>,
            fuelType: args['fuelType'] as String,
          ),
        );

      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case '/favorites':
        return MaterialPageRoute(builder: (_) => const FavoritesScreen());

      case '/videos':
        return MaterialPageRoute(builder: (_) => const UserVideosScreen());

      case '/admin':
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('هەڵە')),
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 🏠 Main Container — بە ProBottomNav
// ═══════════════════════════════════════════════════════════
class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

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

    String _t(String key, String fallback) {
      final t = AppTranslations.t(key, lang);
      return t == key ? fallback : t;
    }

    final navItems = [
      ProNavItem(
        label: _t('nav_home', 'سەرەکی'),
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      ProNavItem(
        label: _t('nav_places', 'شوێنەکان'),
        icon: Icons.location_on_outlined,
        activeIcon: Icons.location_on_rounded,
      ),
      ProNavItem(
        label: _t('nav_categories', 'بەشەکان'),
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
      ),
      ProNavItem(
        label: _t('nav_favorites', 'دڵخواز'),
        icon: Icons.favorite_border_rounded,
        activeIcon: Icons.favorite_rounded,
      ),
      ProNavItem(
        label: _t('nav_daily', 'ڕۆژانە'),
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
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: ProBottomNav(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: navItems,
          enableHaptics: true,
          activeColor: isDark
              ? const Color(0xFF8B5CF6)
              : const Color(0xFF1E88E5),
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

  String _t(String key, String fallback) {
    final t = AppTranslations.t(key, lang);
    return t == key ? fallback : t;
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
                        _buildHeader(context, displayName, displayPhone),
                        const SizedBox(height: 6),

                        // ═══════════════════════════════════════
                        // 🆘 فریاکەوتن — بەشی نوێ
                        // ═══════════════════════════════════════
                        _section('emergency_section', 'فریاکەوتن'),
                        _item(
                          context,
                          icon: Icons.emergency_rounded,
                          color: Colors.red,
                          titleKey: 'nav_emergency',
                          titleFallback: 'فریاکەوتن 🚑',
                          onTap: () =>
                              _push(context, const EmergencyScreen()),
                        ),

                        // ═══════════════════════════════════════
                        // 📅 ڕووداوەکان — بەشی نوێ
                        // ═══════════════════════════════════════
                        _item(
                          context,
                          icon: Icons.event_rounded,
                          color: const Color(0xFF6C5CE7),
                          titleKey: 'nav_events',
                          titleFallback: 'ڕووداوەکان 📅',
                          onTap: () => _push(context, const EventsScreen()),
                        ),

                        const SizedBox(height: 6),
                        _section('nav_guide', 'ڕێبەر'),

                        _item(
                          context,
                          icon: Icons.person_rounded,
                          color: Colors.purple,
                          titleKey: 'nav_profile',
                          titleFallback: 'پرۆفایلم 👤',
                          onTap: () =>
                              _push(context, const ProfileScreen()),
                        ),
                        _item(
                          context,
                          icon: Icons.video_library_rounded,
                          color: Colors.indigo,
                          titleKey: 'nav_videos',
                          titleFallback: 'ڤیدیۆ و ڕێنماییەکان 🎬',
                          onTap: () =>
                              _push(context, const UserVideosScreen()),
                        ),
                        if (isVendor) ...[
                          const SizedBox(height: 8),
                          _section('nav_admin_section', 'بەڕێوەبردن'),
                          _item(
                            context,
                            icon: Icons.admin_panel_settings_rounded,
                            color: Colors.blueGrey,
                            titleKey: 'nav_admin',
                            titleFallback: isAdmin
                                ? 'پانێڵی ئەدمین 👑'
                                : 'پانێڵی بەڕێوەبردن 🏪',
                            onTap: () => _push(
                              context,
                              const AdminDashboardScreen(),
                            ),
                          ),
                        ],
                        const Divider(height: 20),
                        _section('settings', 'ڕێکخستن'),
                        _item(
                          context,
                          icon: Icons.settings_rounded,
                          color: Colors.blueGrey,
                          titleKey: 'settings',
                          titleFallback: 'ڕێکخستنەکان ⚙️',
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
                          titleKey: 'nav_about_me',
                          titleFallback: 'دەربارەی من 👨‍💻',
                          onTap: () => _push(context, const AboutScreen()),
                        ),
                        const Divider(height: 20),
                        if (!isLogged)
                          _item(
                            context,
                            icon: Icons.login_rounded,
                            color: Colors.green,
                            titleKey: 'nav_login',
                            titleFallback:
                            'چوونەژوورەوە / دروستکردنی ئەکاونت',
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
                            titleKey: 'nav_logout',
                            titleFallback: 'چوونەدەرەوە لە هەژمار',
                            onTap: () async {
                              Navigator.pop(context);
                              await AuthSessionManager.clearSession();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_t(
                                      'auth_logout_success',
                                      'بە سەرکەوتوویی چوویتە دەرەوە 👋',
                                    )),
                                  ),
                                );
                              }
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

  Widget _buildHeader(BuildContext context, String name, String phone) {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(
        color: Color(0xFF1E88E5),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      currentAccountPicture: const CircleAvatar(
        backgroundColor: Colors.white,
        child: Icon(
          Icons.person,
          size: 36,
          color: Color(0xFF1E88E5),
        ),
      ),
      accountName: Text(
        name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      accountEmail: Text(
        phone,
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    );
  }

  Widget _section(String key, String fallback) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        _t(key, fallback),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white54 : Colors.grey[600],
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _item(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String titleKey,
        required String titleFallback,
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
          _t(titleKey, titleFallback),
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
          effectiveIsDark
              ? '${_t('settings_theme_dark', 'تاریک')} 🌙'
              : '${_t('settings_theme_light', 'ڕووناک')} ☀️',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        trailing: Switch(
          value: effectiveIsDark,
          onChanged: (value) {
            themeProvider.toggleTheme(value);
          },
          activeThumbColor: const Color(0xFF1E88E5),
        ),
      ),
    );
  }
}