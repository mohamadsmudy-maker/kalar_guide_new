import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// 🤖 خزمەتگوزاری AI بە Gemini
class AiService {
  // ═══════════════════════════════════════════════════════════
  // 🔐 API Key - لە .env
  // ═══════════════════════════════════════════════════════════
  static String get _geminiKey {
    // ✅ لە .env بخوێنەرەوە
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';

    // ✅ ئەگەر .env نەبوو، لە --dart-define هەوڵ بدە
    if (key.isEmpty) {
      return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    }

    return key;
  }

  // ═══════════════════════════════════════════════════════════
  // ⚙️ ڕێکخستن
  // ═══════════════════════════════════════════════════════════
  static const String _model = "gemini-2.0-flash-exp";
  static const String _apiVersion = "v1beta";

  // ═══════════════════════════════════════════════════════════
  // 🎯 فەنکشنی سەرەکی
  // ═══════════════════════════════════════════════════════════
  static Future<String> _callGemini(
      String text, {
        String? base64Image,
      }) async {
    try {
      if (_geminiKey.isEmpty) {
        debugPrint('❌ GEMINI_API_KEY دانەنراوە!');
        return "⚠️ API Key دانەنراوە - تکایە لە .env دایبنێ";
      }

      List<Map<String, dynamic>> parts = [];
      parts.add({"text": text});

      if (base64Image != null) {
        parts.add({
          "inline_data": {
            "mime_type": "image/jpeg",
            "data": base64Image,
          }
        });
      }

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/$_apiVersion/models/$_model:generateContent?key=$_geminiKey',
      );

      debugPrint('🤖 بانگکردنی AI: $_model');

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {"parts": parts}
          ],
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 1024,
          }
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null) {
          return data['candidates'][0]['content']['parts'][0]['text']
              .toString();
        }
        return "⚠️ وەڵام بەتاڵە";
      } else {
        debugPrint('❌ AI Error: ${res.statusCode} - ${res.body}');
        return "⚠️ هەڵەی AI: ${res.statusCode}";
      }
    } catch (e) {
      debugPrint('❌ AI Connection Error: $e');
      return "⚠️ کێشەی پەیوەندی";
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 فەنکشنەکانی تر (هەمان کۆن)
  // ═══════════════════════════════════════════════════════════

  /// دروستکردنی وەسفی کاڵا
  static Future<String> generateDescription(
      String name,
      String price,
      ) async {
    return await _callGemini(
      "You are a copywriter for 'Kalar Guide' (ڕێبەری کەلار) - local city guide and market. Write a 2-line attractive Kurdish Sorani description for: $name with price $price IQD. Use emoji.",
    );
  }

  /// وەڵامدانەوەی کڕیار
  static Future<String> replyToCustomer(String message) async {
    return await _callGemini(
      "You are 'Kalar Assistant' (یاریدەدەری کەلار) for Kalar Guide. Reply in polite Kurdish Sorani to this citizen/customer: $message",
    );
  }

  /// شیکردنەوە بۆ ئەدمین
  static Future<String> askAdminAI(String question, String data) async {
    return await _callGemini(
      "You are the smart municipal and city assistant for Kalar Guide. Data: $data. Question: $question. Answer in short bullet points in Kurdish.",
    );
  }

  /// گەڕانی وێنەیی
  static Future<String> searchByImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );
      if (image == null) return "";

      Uint8List bytes = await image.readAsBytes();
      String base64Image = base64Encode(bytes);

      return await _callGemini(
        "Describe this image for searching in Kalar Guide. Return ONLY 3-4 main keywords in Kurdish Sorani like: رستۆرانت، دەرمانخانە، پێڵاو، مۆبایل. No sentences.",
        base64Image: base64Image,
      );
    } catch (e) {
      return "";
    }
  }

  /// گەڕانی وێنەیی بە فایلی دیاریکراو
  static Future<String> searchByImageGivenFile(XFile imageFile) async {
    try {
      Uint8List bytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(bytes);

      return await _callGemini(
        "ئەم وێنەیە شیکار بکە و تەنها 1 بۆ 2 وشەی سەرەکی کوردی دەربخە بۆ مەبەستی گەڕان لە داتابەیس. هیچ ڕستەیەک مێنوسە.",
        base64Image: base64Image,
      );
    } catch (_) {
      return "گشتی";
    }
  }

  /// پێشنیاری کاڵا
  static Future<String> recommendProducts(
      String currentProductName,
      List<String> availableProducts,
      ) async {
    String prompt =
        "تۆ یاریدەدەری ڕێبەری کەلاریت. کڕیار سەیری ئەم کاڵا یان شوێنەی کردووە: '$currentProductName'. "
        "لە میانەی ئەم لیستەی بەردەست: ${availableProducts.join(', ')}, "
        "تەنها ناوی 2 تا 3 دانە لەم لیستە هەڵبژێرە کە گونجاو بن بۆ پێشنیارکردن بۆی. "
        "تەنها ناوەکان بە بەستەر بە کۆما (،) بنووسە و هیچ دەقێکی تر مێنوسە.";
    return await _callGemini(prompt);
  }

  /// چاککردنی دەقی کوردی
  static Future<String> fixKurdishText(String messyText) async {
    return await _callGemini(
      "ئەم دەقە بکە بە کوردی سۆرانیی ڕەسەن و پاک بۆ ڕێبەری کەلار بێ هیچ زیادەیەک: $messyText",
    );
  }

  /// وەڵامی فرۆشیار
  static Future<String> generateVendorReply(
      String customerQuestion,
      ) async {
    return await _callGemini(
      "تۆ نوێنەری فرۆشگا یان خزمەتگوزاری لە ڕێبەری کەلاریت. کڕیار پرسیوە: '$customerQuestion'. وەڵامێکی کورتی بە ئاداب و ڕوون بە زمانی کوردی سۆرانی بنووسە.",
    );
  }

  /// پێشنیاری نرخ
  static Future<String> suggestProductPrice(String productName) async {
    return await _callGemini(
      "تۆ شارەزای بازاڕی کەلاری. بۆ کاڵای '$productName'، مەودایەکی گونجاوی نرخی فرۆشتن بە دیناری عێراقی (IQD) پێشنیار بکە لەگەڵ هۆکارێکی کورت بە کوردی.",
    );
  }

  /// شیکردنەوەی گەڕان
  static Future<String> parseSmartSearchQuery(String userSentence) async {
    return await _callGemini(
      "ئەم ڕستەیەی بەکارهێنەر شیکار بکە و تەنها وشە سەرەکییەکانی گەڕان بە کوردی سۆرانی (بە کۆما جیاکراوەوە) دەربخە بۆ فلتەرکردن: '$userSentence'. هیچ شتێکی تر مێنوسە.",
    );
  }

  /// پێشنیاری ئایکۆنی بەش
  static Future<String> suggestCategoryIcon(String categoryName) async {
    return await _callGemini(
      "For the category name '$categoryName', choose ONE best matching keyword from this exact list: hospital, school, restaurant, shopping_bag, sports, devices, car, beauty, category. Return ONLY the keyword name, nothing else.",
    );
  }
}