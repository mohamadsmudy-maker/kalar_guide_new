import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 🌍 وەرگێڕانی زیرەک — تێکەڵی Manual + Gemini AI
class TranslationService {
  // ═══════════════════════════════════════════════════════════
  // ⚙️ ڕێکخستن
  // ═══════════════════════════════════════════════════════════
  static const String _cachePrefix = 'ai_trans_v2_';
  static const int _maxCacheEntries = 1000;
  static const Duration _timeout = Duration(seconds: 12);

  static bool _isInitialized = false;
  static String _apiKey = '';
  static final Map<String, String> _memoryCache = {};

  // ═══════════════════════════════════════════════════════════
  // 📚 Dictionary ی دەستی — وشە تەواوەکان
  // ═══════════════════════════════════════════════════════════
  static const Map<String, Map<String, String>> _wordDictionary = {
    // 🏙️ شار و ناوچەکان
    'کەلار': {'ar': 'كلار', 'en': 'Kalar'},
    'گەرمیان': {'ar': 'گرميان', 'en': 'Garmian'},
    'سلێمانی': {'ar': 'السليمانية', 'en': 'Sulaymaniyah'},
    'هەولێر': {'ar': 'أربيل', 'en': 'Erbil'},
    'کەرکووک': {'ar': 'كركوك', 'en': 'Kirkuk'},
    'بەغدا': {'ar': 'بغداد', 'en': 'Baghdad'},
    'کوردستان': {'ar': 'كردستان', 'en': 'Kurdistan'},
    'عێراق': {'ar': 'العراق', 'en': 'Iraq'},

    // 🏘️ گەڕەک و شوێنە باوەکان
    'ئەندازیاران': {'ar': 'المهندسين', 'en': 'Engineers'},
    'لیواکە': {'ar': 'لواء', 'en': 'Liwa'},
    'شەهیدان': {'ar': 'الشهداء', 'en': 'Martyrs'},
    'ئازادی': {'ar': 'الحرية', 'en': 'Azadi'},
    'نەورۆز': {'ar': 'نوروز', 'en': 'Newroz'},
    'ڕزگاری': {'ar': 'التحرير', 'en': 'Rizgari'},
    'گەڕەکی': {'ar': 'حي', 'en': 'District'},
    'شەقام': {'ar': 'شارع', 'en': 'Street'},
    'شەقامی': {'ar': 'شارع', 'en': 'Street of'},

    // 🏷️ کەرتەکان
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

    // 🏢 جۆرەکانی شوێن
    'قوتابخانە': {'ar': 'مدرسة', 'en': 'School'},
    'قوتابخانەی': {'ar': 'مدرسة', 'en': 'School of'},
    'زانکۆ': {'ar': 'جامعة', 'en': 'University'},
    'زانکۆی': {'ar': 'جامعة', 'en': 'University of'},
    'پەیمانگا': {'ar': 'معهد', 'en': 'Institute'},
    'پەیمانگای': {'ar': 'معهد', 'en': 'Institute of'},
    'نەخۆشخانە': {'ar': 'مستشفى', 'en': 'Hospital'},
    'نەخۆشخانەی': {'ar': 'مستشفى', 'en': 'Hospital of'},
    'دەرمانخانە': {'ar': 'صيدلية', 'en': 'Pharmacy'},
    'دەرمانخانەی': {'ar': 'صيدلية', 'en': 'Pharmacy of'},
    'پزیشک': {'ar': 'طبيب', 'en': 'Doctor'},
    'پزیشکخانە': {'ar': 'عيادة', 'en': 'Clinic'},
    'بنکە': {'ar': 'مصرف', 'en': 'Bank'},
    'بنکی': {'ar': 'مصرف', 'en': 'Bank of'},
    'بانک': {'ar': 'مصرف', 'en': 'Bank'},
    'فرۆشگا': {'ar': 'متجر', 'en': 'Store'},
    'فرۆشگای': {'ar': 'متجر', 'en': 'Store of'},
    'دوکان': {'ar': 'دكان', 'en': 'Shop'},
    'دوکانی': {'ar': 'دكان', 'en': 'Shop of'},
    'سوپەرمارکێت': {'ar': 'سوبر ماركت', 'en': 'Supermarket'},
    'ڕێستۆرانت': {'ar': 'مطعم', 'en': 'Restaurant'},
    'چێشتخانە': {'ar': 'مطعم', 'en': 'Restaurant'},
    'چێشتخانەی': {'ar': 'مطعم', 'en': 'Restaurant of'},
    'کافێ': {'ar': 'مقهى', 'en': 'Cafe'},
    'کافێی': {'ar': 'مقهى', 'en': 'Cafe of'},
    'هۆتێل': {'ar': 'فندق', 'en': 'Hotel'},
    'هۆتێلی': {'ar': 'فندق', 'en': 'Hotel of'},
    'شیرینی': {'ar': 'حلويات', 'en': 'Sweets'},
    'شیرینیخانە': {'ar': 'حلويات', 'en': 'Sweets Shop'},
    'قەسابخانە': {'ar': 'جزارة', 'en': 'Butcher'},
    'قەساب': {'ar': 'جزار', 'en': 'Butcher'},
    'نانەوایی': {'ar': 'مخبز', 'en': 'Bakery'},
    'جەراحخانە': {'ar': 'بيطري', 'en': 'Veterinary'},
    'کۆگا': {'ar': 'مخزن', 'en': 'Warehouse'},
    'ئۆفیس': {'ar': 'مكتب', 'en': 'Office'},
    'کۆمپانیا': {'ar': 'شركة', 'en': 'Company'},
    'کۆمپانیای': {'ar': 'شركة', 'en': 'Company of'},
    'فەرمانگە': {'ar': 'دائرة', 'en': 'Department'},
    'فەرمانگەی': {'ar': 'دائرة', 'en': 'Department of'},
    'شارەوانی': {'ar': 'بلدية', 'en': 'Municipality'},
    'شارەوانیی': {'ar': 'بلدية', 'en': 'Municipality of'},
    'قایمقامیەت': {'ar': 'قائممقامية', 'en': 'District Governorate'},
    'پارێزگا': {'ar': 'محافظة', 'en': 'Governorate'},
    'وەزارەت': {'ar': 'وزارة', 'en': 'Ministry'},
    'وەزارەتی': {'ar': 'وزارة', 'en': 'Ministry of'},

    // 🕌 شوێنە ئاینییەکان
    'مزگەوت': {'ar': 'مسجد', 'en': 'Mosque'},
    'مزگەوتی': {'ar': 'مسجد', 'en': 'Mosque of'},
    'جامع': {'ar': 'جامع', 'en': 'Grand Mosque'},
    'حوسێنیە': {'ar': 'حسينية', 'en': 'Husseiniya'},

    // 🏞️ شوێنە گشتییەکان
    'پارک': {'ar': 'حديقة', 'en': 'Park'},
    'پارکی': {'ar': 'حديقة', 'en': 'Park of'},
    'باخ': {'ar': 'بستان', 'en': 'Garden'},
    'یاریگا': {'ar': 'ملعب', 'en': 'Stadium'},
    'یاریگای': {'ar': 'ملعب', 'en': 'Stadium of'},
    'مۆزەخانە': {'ar': 'متحف', 'en': 'Museum'},
    'کتێبخانە': {'ar': 'مكتبة', 'en': 'Library'},

    // 🚗 گواستنەوە
    'بەنزینخانە': {'ar': 'محطة وقود', 'en': 'Gas Station'},
    'بەنزینخانەی': {'ar': 'محطة وقود', 'en': 'Gas Station of'},
    'گەراج': {'ar': 'كراج', 'en': 'Garage'},
    'تەکسی': {'ar': 'تكسي', 'en': 'Taxi'},
    'فڕۆکەخانە': {'ar': 'مطار', 'en': 'Airport'},

    // 👤 کەسەکان و پێداویستییەکان
    'ئافرەت': {'ar': 'نساء', 'en': 'Women'},
    'پیاوان': {'ar': 'رجال', 'en': 'Men'},
    'منداڵان': {'ar': 'أطفال', 'en': 'Children'},
    'جلوبەرگ': {'ar': 'ملابس', 'en': 'Clothing'},
    'پێڵاو': {'ar': 'أحذية', 'en': 'Shoes'},
    'جانتا': {'ar': 'حقائب', 'en': 'Bags'},
    'ئێکسسوارات': {'ar': 'اكسسوارات', 'en': 'Accessories'},
    'زێڕ': {'ar': 'ذهب', 'en': 'Gold'},
    'زیو': {'ar': 'فضة', 'en': 'Silver'},

    // 📱 ئەلیکترۆنیات
    'مۆبایل': {'ar': 'موبايل', 'en': 'Mobile'},
    'کۆمپیوتەر': {'ar': 'كمبيوتر', 'en': 'Computer'},
    'ئەلیکترۆنی': {'ar': 'إلكتروني', 'en': 'Electronic'},

    // 🍔 خواردنەکان
    'شەربەت': {'ar': 'عصير', 'en': 'Juice'},
    'چا': {'ar': 'شاي', 'en': 'Tea'},
    'قاوە': {'ar': 'قهوة', 'en': 'Coffee'},
    'پیتزا': {'ar': 'بيتزا', 'en': 'Pizza'},
    'بەرگر': {'ar': 'برغر', 'en': 'Burger'},

    // 🔤 وشە یاریدەدەرەکان
    'گەورە': {'ar': 'كبير', 'en': 'Grand'},
    'بچووک': {'ar': 'صغير', 'en': 'Small'},
    'ناوەند': {'ar': 'مركزي', 'en': 'Central'},
    'ناوەندی': {'ar': 'مركزي', 'en': 'Central'},
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
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      _apiKey =
      const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    }
    _isInitialized = true;
    debugPrint(_apiKey.isEmpty
        ? '⚠️ TranslationService: GEMINI_API_KEY نەدۆزرایەوە'
        : '✅ TranslationService ئامادەیە (Hybrid Mode)');
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 API ی سەرەکی
  // ═══════════════════════════════════════════════════════════
  static Future<String> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'ku',
  }) async {
    final trimmed = text.trim();

    // ✅ پشکنینی سەرەتا
    if (trimmed.isEmpty) return text;
    if (targetLanguage == sourceLanguage) return text;
    if (targetLanguage == 'ku') return text;

    final cacheKey = '$sourceLanguage|$targetLanguage|$trimmed';

    // ١. Memory Cache
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    // ٢. Disk Cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('$_cachePrefix$cacheKey');
      if (cached != null && cached.isNotEmpty) {
        _memoryCache[cacheKey] = cached;
        return cached;
      }
    } catch (_) {}

    // ٣. Dictionary ی دەستی — دەقی تەواو
    final exactMatch = _wordDictionary[trimmed]?[targetLanguage];
    if (exactMatch != null) {
      _memoryCache[cacheKey] = exactMatch;
      await _saveToDisk(cacheKey, exactMatch);
      debugPrint('📚 [Manual] $trimmed → $exactMatch');
      return exactMatch;
    }

    // ٤. Dictionary ی دەستی — وشە بە وشە
    final hybrid = _hybridTranslate(trimmed, targetLanguage);
    if (hybrid != null && hybrid != trimmed) {
      // ئەگەر لانیکەم ٥٠٪ وشەکان وەرگێڕدراون، بەکاری بهێنە
      _memoryCache[cacheKey] = hybrid;
      await _saveToDisk(cacheKey, hybrid);
      debugPrint('🔀 [Hybrid] $trimmed → $hybrid');
      return hybrid;
    }

    // ٥. Gemini AI — بۆ دەقی ئاڵۆز
    final aiResult = await _aiTranslate(trimmed, targetLanguage);
    _memoryCache[cacheKey] = aiResult;
    await _saveToDisk(cacheKey, aiResult);
    debugPrint('🤖 [AI] $trimmed → $aiResult');
    return aiResult;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔀 وەرگێڕانی وشە بە وشە (Hybrid)
  // ═══════════════════════════════════════════════════════════
  static String? _hybridTranslate(String text, String targetLang) {
    // جیاکردنەوەی وشەکان
    final words = text.split(RegExp(r'\s+'));
    if (words.length < 2) return null; // تەنها یەک وشە

    int translatedCount = 0;
    final result = <String>[];

    for (final word in words) {
      if (word.isEmpty) continue;

      // پاککردنەوەی نیشانەکان
      final cleanWord = word.replaceAll(RegExp(r'[،.,:;!?؟]'), '').trim();

      final translation = _wordDictionary[cleanWord]?[targetLang];
      if (translation != null) {
        result.add(translation);
        translatedCount++;
      } else {
        result.add(word); // وەک خۆی
      }
    }

    // ✅ تەنها ئەگەر لانیکەم ٥٠٪ وشەکان وەرگێڕدرابن
    final ratio = translatedCount / words.length;
    if (ratio < 0.5) return null;

    return result.join(' ');
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 وەرگێڕانی AI (Gemini)
  // ═══════════════════════════════════════════════════════════
  static Future<String> _aiTranslate(
      String text,
      String targetLang,
      ) async {
    _init();
    if (_apiKey.isEmpty) return text;

    try {
      final langName = _langName(targetLang);
      final prompt = '''
You are a professional translator for "Kalar Guide" — a city guide app for Kalar, Kurdistan Region of Iraq.

TASK: Translate the following Kurdish (Sorani) text into $langName.

CONTEXT & RULES:
1. This text is likely a name, address, or category from a Kurdish city.
2. If it's a PERSONAL NAME or BRAND → transliterate to Latin script.
   Example: "قوتابخانەی نامی" → "Nami School" (for English) / "مدرسة نامی" (for Arabic)
3. If it's a NEIGHBORHOOD NAME → transliterate.
   Example: "ئەندازیاران" → "Endaziyaran"
4. If it's a CATEGORY → use the standard term.
   Example: "پەروەردە" → "Education" / "التربية"
5. Keep numbers, English words, and emojis as-is.
6. If unsure, keep it in the original Kurdish.

OUTPUT: Return ONLY the translation, no quotes, no explanation.

TEXT: "$text"

TRANSLATION:''';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$_apiKey',
      );

      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 500,
          },
        }),
      )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['candidates']?[0]?['content']?['parts']?[0]['text']
            ?.toString()
            .trim() ??
            text;

        return _cleanAiOutput(raw, text);
      }

      debugPrint('❌ AI HTTP ${response.statusCode}');
      return text;
    } catch (e) {
      debugPrint('❌ AI error: $e');
      return text;
    }
  }

  /// 🧹 پاککردنەوەی دەرچوونی AI
  static String _cleanAiOutput(String raw, String fallback) {
    var cleaned = raw
        .replaceAll(RegExp(r"""^["'\s]+|["'\s]+$"""), '')      // ✅ چارەسەر
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

      // ✅ LRU cleanup
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

  /// 📊 ئاماری Cache (بۆ Debug)
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

  // ═══════════════════════════════════════════════════════════
  // 🛠️ API ی زیادکردنی وشە (بۆ داهاتوو)
  // ═══════════════════════════════════════════════════════════

  /// 📥 زیادکردنی وشە بۆ Dictionary ی دەستی (لە Runtime)
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

  /// 📖 خوێندنەوەی Dictionary ی دەستی (لە Runtime)
  static Future<String?> getManualWord({
    required String kurdish,
    required String targetLang,
  }) async {
    // یەکەم: Dictionary ی کۆد
    final fromCode = _wordDictionary[kurdish.trim()]?[targetLang];
    if (fromCode != null) return fromCode;

    // دووەم: Dictionary ی Runtime
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('manual_dict_${targetLang}_${kurdish.trim()}');
    } catch (_) {
      return null;
    }
  }
}