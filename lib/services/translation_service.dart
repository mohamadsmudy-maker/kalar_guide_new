import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 🌍 وەرگێڕانی زیرەک — تێکەڵی Manual + Gemini AI
/// ✅ Prompt Injection پارێزراوە بە JSON
class TranslationService {
  static const String _cachePrefix = 'ai_trans_v4_';
  static const int _maxCacheEntries = 1000;
  static const Duration _timeout = Duration(seconds: 15);

  static bool _isInitialized = false;
  static String _apiKey = '';
  static final Map<String, String> _memoryCache = {};

  // ═══════════════════════════════════════════════════════════
  // 📚 Dictionary ی دەستی
  // ═══════════════════════════════════════════════════════════
  static const Map<String, Map<String, String>> _wordDictionary = {
    'کەلار': {'ar': 'كلار', 'en': 'Kalar'},
    'گەرمیان': {'ar': 'گرميان', 'en': 'Garmian'},
    'سلێمانی': {'ar': 'السليمانية', 'en': 'Sulaymaniyah'},
    'هەولێر': {'ar': 'أربيل', 'en': 'Erbil'},
    'کەرکووک': {'ar': 'كركوك', 'en': 'Kirkuk'},
    'بەغدا': {'ar': 'بغداد', 'en': 'Baghdad'},
    'کوردستان': {'ar': 'كردستان', 'en': 'Kurdistan'},
    'عێراق': {'ar': 'العراق', 'en': 'Iraq'},
    'ئەندازیاران': {'ar': 'المهندسين', 'en': 'Engineers'},
    'شەهیدان': {'ar': 'الشهداء', 'en': 'Martyrs'},
    'ئازادی': {'ar': 'الحرية', 'en': 'Azadi'},
    'نەورۆز': {'ar': 'نوروز', 'en': 'Newroz'},
    'ڕزگاری': {'ar': 'التحرير', 'en': 'Rizgari'},
    'گەڕەکی': {'ar': 'حي', 'en': 'District'},
    'شەقام': {'ar': 'شارع', 'en': 'Street'},
    'تەندروستی': {'ar': 'الصحة', 'en': 'Health'},
    'پەروەردە': {'ar': 'التربية', 'en': 'Education'},
    'خوێندنی باڵا': {'ar': 'التعليم العالي', 'en': 'Higher Education'},
    'بەڕێوەبەرایەتی': {'ar': 'الإدارة', 'en': 'Government'},
    'خواردن': {'ar': 'الطعام', 'en': 'Food'},
    'بازاڕگەری': {'ar': 'التسوق', 'en': 'Shopping'},
    'بەنزینخانەکان': {'ar': 'محطات الوقود', 'en': 'Fuel Stations'},
    'وەرزش': {'ar': 'الرياضة', 'en': 'Sports'},
    'گەشتوگوزار': {'ar': 'السياحة', 'en': 'Tourism'},
    'کات بەسەربردن': {'ar': 'الترفيه', 'en': 'Entertainment'},
    'قوتابخانە': {'ar': 'مدرسة', 'en': 'School'},
    'زانکۆ': {'ar': 'جامعة', 'en': 'University'},
    'پەیمانگا': {'ar': 'معهد', 'en': 'Institute'},
    'نەخۆشخانە': {'ar': 'مستشفى', 'en': 'Hospital'},
    'دەرمانخانە': {'ar': 'صيدلية', 'en': 'Pharmacy'},
    'پزیشک': {'ar': 'طبيب', 'en': 'Doctor'},
    'پزیشکخانە': {'ar': 'عيادة', 'en': 'Clinic'},
    'بنکە': {'ar': 'مصرف', 'en': 'Bank'},
    'بانک': {'ar': 'مصرف', 'en': 'Bank'},
    'فرۆشگا': {'ar': 'متجر', 'en': 'Store'},
    'دوکان': {'ar': 'دكان', 'en': 'Shop'},
    'سوپەرمارکێت': {'ar': 'سوبر ماركت', 'en': 'Supermarket'},
    'ڕێستۆرانت': {'ar': 'مطعم', 'en': 'Restaurant'},
    'چێشتخانە': {'ar': 'مطعم', 'en': 'Restaurant'},
    'کافێ': {'ar': 'مقهى', 'en': 'Cafe'},
    'هۆتێل': {'ar': 'فندق', 'en': 'Hotel'},
    'شیرینی': {'ar': 'حلويات', 'en': 'Sweets'},
    'قەسابخانە': {'ar': 'جزارة', 'en': 'Butcher'},
    'نانەوایی': {'ar': 'مخبز', 'en': 'Bakery'},
    'کۆمپانیا': {'ar': 'شركة', 'en': 'Company'},
    'فەرمانگە': {'ar': 'دائرة', 'en': 'Department'},
    'شارەوانی': {'ar': 'بلدية', 'en': 'Municipality'},
    'قایمقامیەت': {'ar': 'قائممقامية', 'en': 'District Governorate'},
    'پارێزگا': {'ar': 'محافظة', 'en': 'Governorate'},
    'وەزارەت': {'ar': 'وزارة', 'en': 'Ministry'},
    'مزگەوت': {'ar': 'مسجد', 'en': 'Mosque'},
    'جامع': {'ar': 'جامع', 'en': 'Grand Mosque'},
    'پارک': {'ar': 'حديقة', 'en': 'Park'},
    'یاریگا': {'ar': 'ملعب', 'en': 'Stadium'},
    'مۆزەخانە': {'ar': 'متحف', 'en': 'Museum'},
    'کتێبخانە': {'ar': 'مكتبة', 'en': 'Library'},
    'بەنزینخانە': {'ar': 'محطة وقود', 'en': 'Gas Station'},
    'گەراج': {'ar': 'كراج', 'en': 'Garage'},
    'تەکسی': {'ar': 'تكسي', 'en': 'Taxi'},
    'فڕۆکەخانە': {'ar': 'مطار', 'en': 'Airport'},
    'ئافرەت': {'ar': 'نساء', 'en': 'Women'},
    'پیاوان': {'ar': 'رجال', 'en': 'Men'},
    'منداڵان': {'ar': 'أطفال', 'en': 'Children'},
    'جلوبەرگ': {'ar': 'ملابس', 'en': 'Clothing'},
    'پێڵاو': {'ar': 'أحذية', 'en': 'Shoes'},
    'جانتا': {'ar': 'حقائب', 'en': 'Bags'},
    'زێڕ': {'ar': 'ذهب', 'en': 'Gold'},
    'زیو': {'ar': 'فضة', 'en': 'Silver'},
    'مۆبایل': {'ar': 'موبايل', 'en': 'Mobile'},
    'کۆمپیوتەر': {'ar': 'كمبيوتر', 'en': 'Computer'},
    'شەربەت': {'ar': 'عصير', 'en': 'Juice'},
    'چا': {'ar': 'شاي', 'en': 'Tea'},
    'قاوە': {'ar': 'قهوة', 'en': 'Coffee'},
    'پیتزا': {'ar': 'بيتزا', 'en': 'Pizza'},
    'گەورە': {'ar': 'كبير', 'en': 'Grand'},
    'بچووک': {'ar': 'صغير', 'en': 'Small'},
    'ناوەند': {'ar': 'مركزي', 'en': 'Central'},
    'نوێ': {'ar': 'جديد', 'en': 'New'},
    'کۆن': {'ar': 'قديم', 'en': 'Old'},
    'سەرەکی': {'ar': 'رئيسي', 'en': 'Main'},
    'تایبەت': {'ar': 'خاص', 'en': 'Private'},
    'گشتی': {'ar': 'عام', 'en': 'Public'},
  };

  // ═══════════════════════════════════════════════════════════
  // 🚀 دەستپێکردن
  // ═══════════════════════════════════════════════════════════
  static void _init() {
    if (_isInitialized) return;

    // ✅ ١. لە .env هەوڵ بدە
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    // ✅ ٢. لە --dart-define هەوڵ بدە
    if (_apiKey.isEmpty) {
      _apiKey = const String.fromEnvironment(
        'GEMINI_API_KEY',
        defaultValue: '',
      );
    }

    _isInitialized = true;

    debugPrint(
      _apiKey.isEmpty
          ? '⚠️ TranslationService: GEMINI_API_KEY نەدۆزرایەوە'
          : '✅ TranslationService ئامادەیە (Hybrid Mode)',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 API ی سەرەکی
  // ═══════════════════════════════════════════════════════════
  static Future<String> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'ku',
  }) async {
    _init(); // ✅ هەمیشە بانگ بکە

    final trimmed = text.trim();

    if (trimmed.isEmpty) return text;
    if (targetLanguage == sourceLanguage) return text;
    if (targetLanguage == 'ku') return text;

    final cacheKey = '$sourceLanguage|$targetLanguage|$trimmed';

    // ✅ Memory Cache
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    // ✅ Disk Cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('$_cachePrefix$cacheKey');
      if (cached != null && cached.isNotEmpty) {
        _memoryCache[cacheKey] = cached;
        return cached;
      }
    } catch (_) {}

    // ✅ Manual Dictionary
    final exactMatch = _wordDictionary[trimmed]?[targetLanguage];
    if (exactMatch != null) {
      _memoryCache[cacheKey] = exactMatch;
      await _saveToDisk(cacheKey, exactMatch);
      debugPrint('📚 [Manual] $trimmed → $exactMatch');
      return exactMatch;
    }

    // ✅ Hybrid
    final hybrid = _hybridTranslate(trimmed, targetLanguage);
    if (hybrid != null && hybrid != trimmed) {
      _memoryCache[cacheKey] = hybrid;
      await _saveToDisk(cacheKey, hybrid);
      debugPrint('🔀 [Hybrid] $trimmed → $hybrid');
      return hybrid;
    }

    // ✅ AI
    final aiResult = await _aiTranslate(trimmed, targetLanguage);
    _memoryCache[cacheKey] = aiResult;
    await _saveToDisk(cacheKey, aiResult);
    return aiResult;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔀 وەرگێڕانی وشە بە وشە (Hybrid)
  // ═══════════════════════════════════════════════════════════
  static String? _hybridTranslate(String text, String targetLang) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length < 2) return null;

    int translatedCount = 0;
    final result = <String>[];

    for (final word in words) {
      if (word.isEmpty) continue;
      final cleanWord = word.replaceAll(RegExp(r'[،.,:;!?؟]'), '').trim();
      final translation = _wordDictionary[cleanWord]?[targetLang];
      if (translation != null) {
        result.add(translation);
        translatedCount++;
      } else {
        result.add(word);
      }
    }

    final ratio = translatedCount / words.length;
    if (ratio < 0.5) return null;

    return result.join(' ');
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 وەرگێڕانی AI — PARANÎ (Prompt Injection پارێزراو)
  // ═══════════════════════════════════════════════════════════
  static Future<String> _aiTranslate(
      String text,
      String targetLang,
      ) async {
    _init();
    if (_apiKey.isEmpty) {
      debugPrint('❌ GEMINI_API_KEY نییە!');
      return text;
    }

    try {
      final langName = _langName(targetLang);

      // ✅ System Instruction
      final systemInstruction = '''
You are a professional translator for "Kalar Guide" (ڕێبەری کەلار) — a city guide app for Kalar, Kurdistan Region of Iraq.

TASK: Translate the given Kurdish (Sorani) text into $langName.

RULES:
1. If it's a PERSONAL NAME or BRAND → transliterate to Latin/Arabic script.
2. If it's a NEIGHBORHOOD name → transliterate.
3. If it's a CATEGORY → use the standard term.
4. Keep numbers, English words, and emojis as-is.
5. If unsure, keep it in the original Kurdish.
6. Return ONLY valid JSON.

OUTPUT FORMAT (must be valid JSON):
{"translation": "your translation here"}
''';

      // ✅ User Content وەک JSON
      final userContent = jsonEncode({
        'text': text,
        'target': targetLang,
      });

      // ✅ مۆدێلی دروست لە .env
      final model = dotenv.env['GEMINI_MODEL'] ?? 'gemini-1.5-flash';
      final apiVersion = dotenv.env['GEMINI_API_VERSION'] ?? 'v1beta';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/$apiVersion/models/$model:generateContent?key=$_apiKey',
      );

      debugPrint('🌐 Translating: "$text" → $langName');
      debugPrint('📡 Model: $model');

      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': systemInstruction}
            ]
          },
          'contents': [
            {
              'parts': [
                {'text': userContent}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 500,
            // ❌ responseMimeType لابرا!
          },
        }),
      )
          .timeout(_timeout);

      debugPrint('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['candidates']?[0]?['content']?['parts']?[0]['text']
            ?.toString()
            .trim() ??
            '';

        if (raw.isEmpty) {
          debugPrint('⚠️ وەڵامی بەتاڵ');
          return text;
        }

        // ✅ پارسکردنی JSON ی پارێزراو
        try {
          final parsed = jsonDecode(raw);
          final translated = parsed['translation']?.toString() ?? text;
          debugPrint('✅ [AI] $text → $translated');
          return _cleanAiOutput(translated, text);
        } catch (_) {
          debugPrint('✅ [AI-Raw] $text → $raw');
          return _cleanAiOutput(raw, text);
        }
      }

      // ✅ هەڵەکان
      if (response.statusCode == 429) {
        debugPrint('⚠️ Rate limit');
        return text;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('❌ API Key هەڵەیە');
        return text;
      }

      debugPrint('❌ AI HTTP ${response.statusCode}: ${response.body}');
      return text;
    } catch (e) {
      debugPrint('❌ AI error: $e');
      return text;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧹 پاککردنەوەی دەرئەنجامی AI
  // ═══════════════════════════════════════════════════════════
  static String _cleanAiOutput(String raw, String fallback) {
    var cleaned = raw
        .replaceAll(RegExp(r"""^["'\s]+|["'\s]+$"""), '')
        .replaceAll(RegExp(r'^(Translation|وەرگێڕان|الترجمة)\s*:\s*'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();

    if (cleaned.isEmpty || cleaned.length > 500) {
      return fallback;
    }
    return cleaned;
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 Cache Management
  // ═══════════════════════════════════════════════════════════
  static Future<void> _saveToDisk(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$key', value);

      final keys =
      prefs.getKeys().where((k) => k.startsWith(_cachePrefix)).toList();
      if (keys.length > _maxCacheEntries) {
        final toRemove = keys.take(keys.length - _maxCacheEntries);
        for (final k in toRemove) {
          await prefs.remove(k);
        }
      }
    } catch (_) {}
  }

  static Future<void> clearCache() async {
    _memoryCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  static Map<String, int> getCacheStats() {
    return {
      'memory': _memoryCache.length,
      'dictionary': _wordDictionary.length,
    };
  }

  static String _langName(String code) {
    switch (code) {
      case 'ar':
        return 'Arabic';
      case 'en':
        return 'English';
      case 'ku':
        return 'Kurdish Sorani';
      default:
        return 'English';
    }
  }

  static Future<void> addManualWord({
    required String kurdish,
    required String targetLang,
    required String translation,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'manual_dict_${targetLang}_$kurdish';
      await prefs.setString(key, translation);
      debugPrint('✅ وشەی نوێ زیادکرا: $kurdish → $translation');
    } catch (_) {}
  }

  static Future<String?> getManualWord({
    required String kurdish,
    required String targetLang,
  }) async {
    final fromCode = _wordDictionary[kurdish.trim()]?[targetLang];
    if (fromCode != null) return fromCode;

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('manual_dict_${targetLang}_${kurdish.trim()}');
    } catch (_) {
      return null;
    }
  }
}