import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
// 🔌 Supabase Client
// ═══════════════════════════════════════════════════════════

/// Lazily resolves the Supabase client.
///
/// Override in tests:
/// ```dart
/// ProviderScope(
///   overrides: [supabaseProvider.overrideWithValue(fakeClient)],
///   child: ...,
/// )
/// ```
final supabaseProvider = Provider<SupabaseClient>((ref) {
  try {
    return Supabase.instance.client;
  } catch (e, st) {
    debugPrint('❌ supabaseProvider: Supabase not initialized.\n$e\n$st');
    throw StateError(
      'Supabase has not been initialized. '
          'Call `await Supabase.initialize(url: ..., anonKey: ...)` '
          'in main() before running the app.',
    );
  }
});

/// Whether the current Supabase user is authenticated.
/// Rebuilds whenever auth state changes (login, logout, token refresh).
final supabaseAuthStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseProvider);
  return client.auth.onAuthStateChange;
});

/// Convenience: the current Supabase `User` (may be null).
final supabaseUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseProvider).auth.currentUser;
});

/// Convenience: whether a Supabase session exists.
final isSupabaseAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(supabaseProvider).auth.currentSession != null;
});

// ═══════════════════════════════════════════════════════════
// 💾 SharedPreferences
// ═══════════════════════════════════════════════════════════

/// Must be overridden in `ProviderScope` with the real instance:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final prefs = await SharedPreferences.getInstance();
///   runApp(
///     ProviderScope(
///       overrides: [
///         sharedPreferencesProvider.overrideWithValue(prefs),
///       ],
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
///
/// Or, use [sharedPreferencesAsyncProvider] below for zero-boilerplate.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a real instance. '
        'See main() for the recommended bootstrap.',
  );
});

/// Async version — fetches SharedPreferences on first access.
/// Prefer this in new code; use [sharedPreferencesProvider] when you
/// already initialized it in `main()` for synchronous reads.
final sharedPreferencesAsyncProvider =
FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

// ═══════════════════════════════════════════════════════════
// ⚙️ App Config / Environment
// ═══════════════════════════════════════════════════════════

/// Build-time environment. Override in tests / flavors.
@immutable
class AppConfig {
  final bool isDebug;
  final bool isRelease;
  final bool isProfile;
  final String appName;
  final String appVersion;
  final Duration networkTimeout;
  final String supabaseUrl;
  final String supabaseAnonKey;

  const AppConfig({
    required this.isDebug,
    required this.isRelease,
    required this.isProfile,
    this.appName = 'app',
    this.appVersion = '0.0.0',
    this.networkTimeout = const Duration(seconds: 15),
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
  });

  factory AppConfig.fromBuild() {
    return const AppConfig(
      isDebug: kDebugMode,
      isRelease: kReleaseMode,
      isProfile: kProfileMode,
      appName: String.fromEnvironment('APP_NAME', defaultValue: 'Kalar Guide'),
      appVersion: String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0'),
      networkTimeout: Duration(seconds: 15),
      supabaseUrl: String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
      supabaseAnonKey:
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
    );
  }

  bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  AppConfig copyWith({
    bool? isDebug,
    bool? isRelease,
    bool? isProfile,
    String? appName,
    String? appVersion,
    Duration? networkTimeout,
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) {
    return AppConfig(
      isDebug: isDebug ?? this.isDebug,
      isRelease: isRelease ?? this.isRelease,
      isProfile: isProfile ?? this.isProfile,
      appName: appName ?? this.appName,
      appVersion: appVersion ?? this.appVersion,
      networkTimeout: networkTimeout ?? this.networkTimeout,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AppConfig &&
              isDebug == other.isDebug &&
              isRelease == other.isRelease &&
              isProfile == other.isProfile &&
              appName == other.appName &&
              appVersion == other.appVersion &&
              networkTimeout == other.networkTimeout &&
              supabaseUrl == other.supabaseUrl &&
              supabaseAnonKey == other.supabaseAnonKey;

  @override
  int get hashCode => Object.hash(
    isDebug,
    isRelease,
    isProfile,
    appName,
    appVersion,
    networkTimeout,
    supabaseUrl,
    supabaseAnonKey,
  );
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromBuild();
});

// ═══════════════════════════════════════════════════════════
// 📝 Logger
// ═══════════════════════════════════════════════════════════

enum LogLevel { debug, info, warning, error }

/// Simple logger abstraction so `debugPrint` isn't scattered around.
/// Swap for `logger` package or Sentry later without touching call sites.
class AppLogger {
  final bool enabled;
  final LogLevel minLevel;

  const AppLogger({
    this.enabled = kDebugMode,
    this.minLevel = LogLevel.debug,
  });

  bool _shouldLog(LogLevel level) {
    if (!enabled) return false;
    return level.index >= minLevel.index;
  }

  void d(String tag, Object? message) {
    if (_shouldLog(LogLevel.debug)) debugPrint('🐛 [$tag] $message');
  }

  void i(String tag, Object? message) {
    if (_shouldLog(LogLevel.info)) debugPrint('ℹ️  [$tag] $message');
  }

  void w(String tag, Object? message, [Object? error, StackTrace? st]) {
    if (_shouldLog(LogLevel.warning)) {
      debugPrint('⚠️  [$tag] $message');
      if (error != null) debugPrint('   └─ $error');
      if (st != null) debugPrint('   └─ $st');
    }
  }

  void e(String tag, Object? message, [Object? error, StackTrace? st]) {
    // ✅ Always log errors (even in release) — hook up Sentry/Crashlytics here
    debugPrint('❌ [$tag] $message');
    if (error != null) debugPrint('   └─ $error');
    if (st != null) debugPrint('   └─ $st');
  }
}

final appLoggerProvider = Provider<AppLogger>((ref) => const AppLogger());

// ═══════════════════════════════════════════════════════════
// 🔗 Connectivity
// ═══════════════════════════════════════════════════════════

/// Emits `true` when the device has ANY connection (wifi/mobile/ethernet).
/// Emits `false` when fully offline.
///
/// Use:
/// ```dart
/// final isOnline = ref.watch(isOnlineProvider);
/// ```
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  // Seed with current status to avoid long delay on first frame.
  final controller = StreamController<bool>();
  StreamSubscription<List<ConnectivityResult>>? sub;

  Future<void> bootstrap() async {
    try {
      final results = await connectivity.checkConnectivity();
      if (!controller.isClosed) {
        controller.add(!results.contains(ConnectivityResult.none));
      }
    } catch (e) {
      if (!controller.isClosed) controller.add(true); // assume online
    }

    sub = connectivity.onConnectivityChanged.listen(
          (results) {
        if (!controller.isClosed) {
          controller.add(!results.contains(ConnectivityResult.none));
        }
      },
      onError: (Object e, StackTrace st) {
        ref.read(appLoggerProvider).w('connectivity', e, e, st);
      },
    );
  }

  unawaited(bootstrap());

  ref.onDispose(() {
    sub?.cancel();
    controller.close();
  });

  return controller.stream.distinct();
});

/// Convenience bool — `true` if currently online.
/// Defaults to `true` while the first event is loading.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).maybeWhen(
    data: (online) => online,
    orElse: () => true,
  );
});

// ═══════════════════════════════════════════════════════════
// 🔔 Riverpod Observer (log every state transition)
// ═══════════════════════════════════════════════════════════

/// Register in `main()`:
/// ```dart
/// ProviderScope(
///   observers: [RiverpodLogger(verbose: kDebugMode)],
///   ...
/// )
/// ```
class RiverpodLogger extends ProviderObserver {
  final bool verbose;
  const RiverpodLogger({this.verbose = false});

  @override
  void didUpdateProvider(
      ProviderBase<Object?> provider,
      Object? previousValue,
      Object? newValue,
      ProviderContainer container,
      ) {
    if (!verbose) return;
    debugPrint(
      '🔄 [Riverpod] ${provider.name ?? provider.runtimeType} → $newValue',
    );
  }

  @override
  void didAddProvider(
      ProviderBase<Object?> provider,
      Object? value,
      ProviderContainer container,
      ) {
    if (!verbose) return;
    debugPrint(
      '➕ [Riverpod] ${provider.name ?? provider.runtimeType} created: $value',
    );
  }

  @override
  void didDisposeProvider(
      ProviderBase<Object?> provider,
      ProviderContainer container,
      ) {
    if (!verbose) return;
    debugPrint(
      '🗑  [Riverpod] ${provider.name ?? provider.runtimeType} disposed',
    );
  }

  @override
  void providerDidFail(
      ProviderBase<Object?> provider,
      Object error,
      StackTrace stackTrace,
      ProviderContainer container,
      ) {
    debugPrint(
      '💥 [Riverpod] ${provider.name ?? provider.runtimeType} failed: $error\n$stackTrace',
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🧪 Test Overrides Helper
// ═══════════════════════════════════════════════════════════

/// Returns standard overrides for widget/unit tests.
///
/// ```dart
/// testWidgets('...', (tester) async {
///   SharedPreferences.setMockInitialValues({});
///   final prefs = await SharedPreferences.getInstance();
///   await tester.pumpWidget(
///     ProviderScope(
///       overrides: testOverrides(prefs: prefs),
///       child: MyApp(),
///     ),
///   );
/// });
/// ```
List<Override> testOverrides({
  SharedPreferences? prefs,
  SupabaseClient? supabase,
  AppConfig? config,
  AppLogger? logger,
  bool? isOnline,
}) {
  return [
    if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
    if (supabase != null) supabaseProvider.overrideWithValue(supabase),
    if (config != null) appConfigProvider.overrideWithValue(config),
    if (logger != null) appLoggerProvider.overrideWithValue(logger),
    if (isOnline != null)
      isOnlineProvider.overrideWithValue(isOnline),
  ];
}