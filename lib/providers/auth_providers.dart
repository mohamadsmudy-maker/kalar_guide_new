import 'package:flutter/foundation.dart';  // ✅ بۆ debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/auth_repository.dart';
import '../models/user.dart';
import 'providers.dart';

// ═══════════════════════════════════════════════════════════
// 🔐 Auth Repository Provider
// ═══════════════════════════════════════════════════════════
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return AuthRepository(client);
});

// ═══════════════════════════════════════════════════════════
// 🔐 State ی بەکارهێنەر
// ═══════════════════════════════════════════════════════════
class AuthState {
  final AppUser? user;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
  });

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.role == 'admin';
  bool get isVendor => user?.role == 'vendor' || isAdmin;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    bool? isInitialized,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎯 Notifier ی Auth
// ═══════════════════════════════════════════════════════════
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  static const String _phoneKey = 'logged_phone';

  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }

  /// ✅ دەستپێکردن
  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString(_phoneKey);

      if (phone == null || phone.isEmpty) {
        state = state.copyWith(isInitialized: true);
        return;
      }

      final user = await _repo.getUserByPhone(phone);
      state = AuthState(
        user: user,
        isInitialized: true,
      );
    } catch (e) {
      state = state.copyWith(
        isInitialized: true,
        error: e.toString(),
      );
    }
  }

  /// ✅ چوونەژوورەوە
  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _repo.login(
        phone: phone,
        password: password,
      );

      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'مۆبایل یان پاسۆرد هەڵەیە',
        );
        return false;
      }

      if (user.role == 'pending') {
        state = state.copyWith(
          isLoading: false,
          error: 'چاوەڕوانی پەسەندکردن',
        );
        return false;
      }

      // ✅ پاشەکەوتکردن
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_phoneKey, phone);

      state = AuthState(
        user: user,
        isLoading: false,
        isInitialized: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// ✅ دروستکردنی ئەکاونت
  Future<bool> signUp({
    required String name,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _repo.signUp(
        name: name,
        phone: phone,
        password: password,
      );

      if (!success) {
        state = state.copyWith(
          isLoading: false,
          error: 'نەتوانرا ئەکاونت دروست بکرێت',
        );
        return false;
      }

      // ✅ دوای SignUp، Login بکە
      return await login(phone: phone, password: password);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// ✅ چوونەدەرەوە
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_phoneKey);

      state = const AuthState(isInitialized: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// ✅ نوێکردنەوەی پرۆفایل
  Future<void> refreshProfile() async {
    if (state.user?.phone == null) return;

    try {
      final user = await _repo.getUserByPhone(state.user!.phone!);
      if (user != null) {
        state = state.copyWith(user: user);
      }
    } catch (e) {
      // ✅ ئێستا debugPrint کار دەکات چونکە import ەکە هەیە
      debugPrint('❌ AuthNotifier.refreshProfile: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 🎯 Provider ی سەرەکی
// ═══════════════════════════════════════════════════════════
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});