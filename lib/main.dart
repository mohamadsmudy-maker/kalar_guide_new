import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_colors.dart';
import 'config/settings_provider.dart';
import 'config/theme.dart';
import 'config/theme_provider.dart';
import 'config/translations.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/categories/categories_screen.dart';
import 'screens/categories/category_details.dart';
import 'screens/daily/daily_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/fuel/fuel_prices_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/search/global_search.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/stores/stores_screen.dart';
import 'screens/videos/user_videos.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'utils/app_logger.dart';
import 'utils/kurdish_localizations.dart';

// ═══════════════════════════════════════════════════════════
// 🌍 Global Keys — بۆ Navigation و Snackbar لە Services
// ═══════════════════════════════════════════════════════════
final GlobalKey<NavigatorState> appNavigatorKey =
GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
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
    AppLogger.e('FCM background handler failed', e);
  }
}

// ═══════════════════════════════════════════════════════════
// 🚀 main()
// ═══════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();

  // ✅ ١. یەکەم: .env + Supabase
  await _loadEnv();
  await _initSupabase();

  // ✅ ٢. Firebase — چاوەڕوانی بکە (پێویستە بۆ Notifications)
  await _initFirebase();

  // ✅ ٣. Session + Notifications — ئێستا Firebase ئامادەیە
  _initSessionAndNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const BazaryXanmanApp(),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// 📦 Initialization Helpers
// ═══════════════════════════════════════════════════════════
Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
    AppLogger.i('✅ .env بارکرا');
  } catch (e) {
    AppLogger.e('❌ .env نەتوانرا باربکرێت', e);
    throw StateError('❌ .env missing — place it in project root');
  }
}

Future<void> _initSupabase() async {
  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (url.isEmpty || key.isEmpty) {
    if (kReleaseMode) {
      throw StateError(
        '❌ SUPABASE_URL / SUPABASE_ANON_KEY missing in .env',
      );
    }
    AppLogger.w('⚠️ Supabase config missing — app may not work');
    return;
  }

  await Supabase.initialize(url: url, anonKey: key);
  AppLogger.i('✅ Supabase initialized');
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
    AppLogger.i('✅ Firebase initialized');
  } catch (e) {
    // ⚠️ نابێت ئەپەکە بکوژێت — تەنها Notifications ناچالاک دەبن
    AppLogger.e('❌ Firebase init failed — notifications disabled', e);
  }
}

/// ✅ ئەمە لە background دا کار دەکات — Splash چاوەڕوانی دەکات
Future<void> _initSessionAndNotifications() async {
  try {
    await AuthSessionManager.initSession();
    AppLogger.i('✅ Session initialized');

    await NotificationService.initialize();
    AppLogger.i('✅ Notification Service ready');

    if (AuthSessionManager.currentUser != null) {
      await NotificationService.refreshToken();
      AppLogger.i('✅ FCM Token refreshed');
    }
  } catch (e) {
    AppLogger.e('❌ Session/Notifications init failed', e);
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 App Widget
// ═══════════════════════════════════════════════════════════
class BazaryXanmanApp extends StatelessWidget {
  const BazaryXanmanApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Provider ها لە MultiProvider دا هەن — دەتوانین بیخوێنینەوە
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final locale = settingsProvider.locale;
    final isRtl = settingsProvider.isRtl;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "ڕێبەری کەلار",
      locale: locale,

      // ✅ Global Keys
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,

      // ✅ Delegates — Kurdish + Global بۆ هەموو Locale
      localizationsDelegates: const [
        // Kurdish — پێش Global دابنێ بۆ ئەولەویەت
        KurdishMaterialLocalizationsDelegate(),
        KurdishCupertinoLocalizationsDelegate(),
        KurdishWidgetsLocalizationsDelegate(),
        // Global — Fallback بۆ زمانەکانی تر
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ku', 'IQ'),
        Locale('ar', 'AE'),
        Locale('en', 'US'),
      ],

      // ✅ TextTheme بە Cache
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

      onGenerateRoute: _generateRoute,

      home: const SplashScreen(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗺️ Route Generator — پارێزراو
  // ═══════════════════════════════════════════════════════════
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/main':
        return MaterialPageRoute(
          builder: (_) => const MainContainerScreen(),
        );

      case '/auth':
        return MaterialPageRoute(builder: (_) => const AuthScreen());

      case '/settings':
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );

      case '/category':
        final catName = settings.arguments as String?;
        if (catName == null || catName.trim().isEmpty) {
          AppLogger.w('⚠️ /category called without arguments');
          return MaterialPageRoute(
            builder: (_) => const CategoriesScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => CategoryDetailsScreen(categoryName: catName),
        );

      case '/fuel':
        return MaterialPageRoute(
          builder: (_) => const FuelPricesScreen(),
        );

      default:
        AppLogger.w('⚠️ Route not found: ${settings.name}');
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('هەڵە')),
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 🏠 Main Container — بە Lazy Loading
// ═══════════════════════════════════════════════════════════
class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int _currentIndex = 0;

  // ✅ Lazy Loading — شاشەیەک تەنها کاتێک دروست دەکرێت
  final Set<int> _loadedTabs = {0};

  @override
  void initState() {
    super.initState();
    _loadedTabs.add(0);
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
    });
  }

  Widget _buildTab(int index) {
    if (!_loadedTabs.contains(index)) {
      return const SizedBox.shrink();
    }

    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const StoresScreen();
      case 2:
        return const CategoriesScreen();
      case 3:
        return const FavoritesScreen();
      case 4:
        return const DailyScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final lang = settings.languageId;

    // ✅ PopScope — Back button سەرەتا بۆ Tab ٠ دەگەڕێتەوە
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        extendBody: true,
        appBar: _buildAppBar(isDark, lang),
        drawer: _AppDrawer(lang: lang, isDark: isDark),
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(5, _buildTab),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          labelBehavior:
          NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            _navDest(
              'nav_home',
              'سەرەکی',
              Icons.home_outlined,
              Icons.home_rounded,
              lang,
            ),
            _navDest(
              'nav_places',
              'شوێنەکان',
              Icons.place_outlined,
              Icons.place_rounded,
              lang,
            ),
            _navDest(
              'nav_categories',
              'بەشەکان',
              Icons.grid_view_outlined,
              Icons.grid_view_rounded,
              lang,
            ),
            _navDest(
              'nav_favorites',
              'دڵخواز',
              Icons.favorite_border_outlined,
              Icons.favorite_rounded,
              lang,
            ),
            _navDest(
              'nav_daily',
              'ڕۆژانە ⚡',
              Icons.today_rounded,
              Icons.calendar_today_rounded,
              lang,
            ),
          ],
        ),
      ),
    );
  }

  NavigationDestination _navDest(
      String key,
      String fallback,
      IconData icon,
      IconData selectedIcon,
      String lang,
      ) {
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: key.tr(lang, fallback: fallback),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, String lang) {
    return AppBar(
      toolbarHeight: 76,
      titleSpacing: 18,
      backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          tooltip: 'لیست',
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white : AppColors.primary,
          ),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_rounded,
            color: isDark ? Colors.cyanAccent : AppColors.primary,
            size: 26,
          ),
          const SizedBox(width: 8),
          Text(
            'app_name'.tr(lang, fallback: 'ڕێبەری کەلار'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.primary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'گەڕان',
          icon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white : AppColors.primary,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GlobalSearchScreen(),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.84,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(30)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Container(
            color:
            isDark ? const Color(0xFF121218) : const Color(0xFFFCFAFC),
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: AuthSessionManager.userNotifier,
                  builder: (context, userProfile, _) {
                    final isLogged = userProfile != null;
                    final role =
                        userProfile?['role']?.toString() ?? 'customer';

                    final isAdmin = role == 'admin';
                    final isVendor = role == 'vendor';

                    final displayName = isLogged
                        ? (userProfile['name']?.toString() ?? 'بەکارهێنەر')
                        : 'welcome_guest'.tr(lang,
                        fallback: 'میوانی خۆشەویست');

                    final displayPhone = isLogged
                        ? (userProfile['phone']?.toString() ?? '')
                        : 'کرتە بکە بۆ چوونەژوورەوە';

                    return ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildHeader(context, displayName, displayPhone),
                        const SizedBox(height: 6),

                        // 🧭 بەشی ڕێبەر
                        _section('nav_guide', 'ڕێبەر'),
                        _item(context,
                            icon: Icons.shopping_cart_rounded,
                            color: Colors.blue,
                            titleKey: 'nav_cart',
                            titleFallback: 'سەبەتەی کڕین 🛒',
                            onTap: () =>
                                _push(context, const CartScreen())),
                        _item(context,
                            icon: Icons.receipt_long_rounded,
                            color: Colors.teal,
                            titleKey: 'nav_orders',
                            titleFallback: 'داواکارییەکانم',
                            onTap: () =>
                                _push(context, const OrdersScreen())),
                        _item(context,
                            icon: Icons.person_rounded,
                            color: Colors.purple,
                            titleKey: 'nav_profile',
                            titleFallback: 'پرۆفایلم 👤',
                            onTap: () =>
                                _push(context, const ProfileScreen())),
                        _item(context,
                            icon: Icons.video_library_rounded,
                            color: Colors.indigo,
                            titleKey: 'nav_videos',
                            titleFallback: 'ڤیدیۆ و ڕێنماییەکان 🎬',
                            onTap: () =>
                                _push(context, const UserVideosScreen())),

                        // 👑 بەشی ئەدمین — تەنها بۆ Admin
                        if (isAdmin) ...[
                          const SizedBox(height: 8),
                          _section('nav_admin_section', 'بەڕێوەبردن'),
                          _item(context,
                              icon: Icons.admin_panel_settings_rounded,
                              color: Colors.blueGrey,
                              titleKey: 'nav_admin',
                              titleFallback: 'ژووری ئەدمین 👑',
                              onTap: () => _push(
                                context,
                                const AdminDashboardScreen(),
                              )),
                        ]
                        // 🏪 بەشی فرۆشیار — تەنها بۆ Vendor
                        else if (isVendor) ...[
                          const SizedBox(height: 8),
                          _section('nav_vendor_section', 'فرۆشیار'),
                          _item(context,
                              icon: Icons.store_rounded,
                              color: Colors.orange,
                              titleKey: 'nav_my_store',
                              titleFallback: 'شوێنەکەم 🏪',
                              onTap: () {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'بەشی فرۆشیار بەم زووانە دێت'),
                                  ),
                                );
                              }),
                        ],

                        const Divider(height: 20),

                        // ⚙️ ڕێکخستن
                        _section('settings', 'ڕێکخستن'),
                        _item(context,
                            icon: Icons.settings_rounded,
                            color: Colors.blueGrey,
                            titleKey: 'settings',
                            titleFallback: 'ڕێکخستنەکان ⚙️',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/settings');
                            }),
                        _themeSwitch(context, themeProvider),

                        const Divider(height: 20),

                        // 🚪 چوونەژوورەوە / چوونەدەرەوە
                        if (!isLogged)
                          _item(context,
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
                              })
                        else
                          _item(context,
                              icon: Icons.logout_rounded,
                              color: Colors.redAccent,
                              textColor: Colors.redAccent,
                              titleKey: 'nav_logout',
                              titleFallback: 'چوونەدەرەوە لە هەژمار',
                              onTap: () async {
                                Navigator.pop(context);
                                await AuthSessionManager.clearSession();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'auth_logout_success'.tr(
                                          lang,
                                          fallback:
                                          'بە سەرکەوتوویی چوویتە دەرەوە 👋',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }),

                        const SizedBox(height: 20),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildHeader(
      BuildContext context,
      String name,
      String phone,
      ) {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      currentAccountPicture: const CircleAvatar(
        backgroundColor: Colors.white,
        child: Icon(Icons.person, size: 36, color: AppColors.primary),
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
        key.tr(lang, fallback: fallback),
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
      color: Colors.transparent,
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
          titleKey.tr(lang, fallback: titleFallback),
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
    final isDarkMode = themeProvider.isDarkMode;
    final accentColor = isDarkMode ? Colors.orange : Colors.purple;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            isDarkMode
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            color: accentColor,
            size: 20,
          ),
        ),
        title: Text(
          isDarkMode
              ? 'settings_theme_dark'.tr(lang, fallback: 'تاریک 🌙')
              : 'settings_theme_light'.tr(lang, fallback: 'ڕووناک ☀️'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        trailing: Switch(
          value: isDarkMode,
          onChanged: themeProvider.toggleTheme,
          activeThumbColor: AppColors.primary,
        ),
        onTap: () => themeProvider.toggleTheme(!isDarkMode),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🌍 Extension — بۆ کورتکردنەوەی Fallback Pattern
// ═══════════════════════════════════════════════════════════
extension TranslateExt on String {
  /// ئەگەر وەرگێڕان نەدۆزرایەوە، fallback بەکاربهێنە
  String tr(String lang, {String? fallback}) {
    final t = AppTranslations.t(this, lang);
    return t == this ? (fallback ?? this) : t;
  }
}