// lib/services/ai_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🤖 خزمەتگوزاری AI — بە Edge Function
///
/// ✅ کلیلەکە لە server دەمێنێت، هەرگیز لە client نابێت
class AiService {
  AiService._();

  // ═══════════════════════════════════════════════════════════
  // 🎯 فەنکشنی سەرەکی
  // ═══════════════════════════════════════════════════════════
  static Future<String> _callGemini(
      String text, {
        String? base64Image,
        Duration timeout = const Duration(seconds: 30),
      }) async {
    try {
      if (text.trim().isEmpty) {
        return '⚠️ دەقەکە بەتاڵە';
      }

      final response = await Supabase.instance.client.functions
          .invoke(
        'gemini-proxy',
        body: {
          'prompt': text,
          'base64Image': base64Image,
          'maxTokens': 2048,
          'temperature': 0.7,
        },
      )
          .timeout(timeout);

      if (response.status != 200) {
        debugPrint('❌ AI error: ${response.status}');
        if (response.status == 429) {
          return '⚠️ زۆر داواکاریت ناردووە — تکایە کەمێک چاوەڕوان بە';
        }
        return '⚠️ هەڵەی AI: ${response.status}';
      }

      final data = response.data as Map<String, dynamic>?;
      final aiText = data?['text']?.toString() ?? '';

      return aiText.isEmpty ? '⚠️ وەڵام بەتاڵە' : aiText;
    } catch (e) {
      debugPrint('❌ AI connection error: $e');
      if (e.toString().contains('TimeoutException')) {
        return '⚠️ کاتەکە تێپەڕی — تکایە دووبارە هەوڵ بدە';
      }
      return '⚠️ کێشەی پەیوەندی';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 فەنکشنەکانی تر
  // ═══════════════════════════════════════════════════════════

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
      debugPrint('❌ Search by image error: $e');
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
    } catch (e) {
      debugPrint('❌ searchByImageGivenFile error: $e');
      return "گشتی";
    }
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