// lib/services/place_names_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'translation_service.dart';

/// 🔤 شوێنەکان کە ناویان بە لاتینییە (زۆربەیان لە OpenStreetMap ـەوە)
/// → پێشنیاری ناوی کوردی بە Gemini، و پاشەکەوتکردن.
class PlaceNamesService {
  PlaceNamesService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static final RegExp _latin = RegExp(r'[A-Za-z]');
  static final RegExp _arabicScript = RegExp(r'[؀-ۿ]');

  /// ناوەکە پیتی لاتینیی تێدایە و هیچ پیتی کوردی/عەرەبی نییە
  static bool isLatinName(String name) =>
      _latin.hasMatch(name) && !_arabicScript.hasMatch(name);

  /// هەموو شوێنە لاتینییەکان (id, name, category)
  static Future<List<Map<String, dynamic>>> latinPlaces() async {
    final rows = List<Map<String, dynamic>>.from(
        await _db.from('dukan').select('id, name, category').order('name') as List);
    return [for (final r in rows) if (isLatinName('${r['name'] ?? ''}')) r];
  }

  /// پێشنیاری ناوی کوردی (زۆرترین ٥٠ لە یەک جار)
  static Future<List<String>> suggestKurdish(List<String> names) async {
    final res = await _db.functions.invoke('translate-text',
        body: {'mode': 'to_kurdish', 'names': names});
    final data = res.data;
    final list = data is Map ? data['kurdish'] : null;
    if (list is! List || list.length != names.length) {
      throw Exception(data is Map ? '${data['error'] ?? 'bad reply'}' : 'bad reply');
    }
    return [for (final v in list) '$v'.trim()];
  }

  /// ناوی کوردی پاشەکەوت دەکات. ناوە لاتینییە کۆنەکە دەبێتە وەرگێڕانی
  /// ئینگلیزی، بۆیە بەکارهێنەرانی ئینگلیزی هێشتا هەمان ناو دەبینن.
  static Future<void> rename(Object id, {required String oldName, required String newName}) async {
    final name = newName.trim();
    if (name.isEmpty || name == oldName) return;
    await _db.from('dukan').update({'name': name}).eq('id', id);
    if (isLatinName(oldName)) {
      try {
        await _db.from('text_translations').upsert({
          'lang': 'en',
          'source': name,
          'translation': oldName.trim(),
          'edited': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'lang,source_hash');
      } catch (e) {
        debugPrint('⚠️ keep english name: $e');
      }
    }
  }

  static void refreshTranslations() => TranslationService.syncShared('en');
}
