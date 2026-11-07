import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ───────────────────────────────────────────────
// 📦 Category Repository
// ───────────────────────────────────────────────
class CategoryRepository {
  final SupabaseClient _client;
  CategoryRepository(this._client);

  Future<List<Map<String, dynamic>>> getMainCategories() async {
    try {
      final res = await _client
          .from('main_categories')
          .select('id, name, image')
          .order('id', ascending: true);

      final unique = <String, Map<String, dynamic>>{};
      for (final row in List<Map<String, dynamic>>.from(res as List)) {
        final name = row['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        unique.putIfAbsent(name, () => row);
      }
      return unique.values.toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('❌ CategoryRepository.getMainCategories: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ CategoryRepository.getMainCategories: $e');
      rethrow;
    }
  }
}

// ───────────────────────────────────────────────
// 📦 Providers
// ───────────────────────────────────────────────
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(Supabase.instance.client);
});

final mainCategoriesProvider =
FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getMainCategories();
});