import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
// 🔌 Supabase Client
// ═══════════════════════════════════════════════════════════
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ═══════════════════════════════════════════════════════════
// 💾 SharedPreferences
// ═══════════════════════════════════════════════════════════
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});