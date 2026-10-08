import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🎤 خزمەتگوزاری تۆمارکردن و بارکردنی دەنگ
class AudioService {
  static final AudioRecorder _recorder = AudioRecorder();
  static bool _isInitialized = false;
  static bool _isRecording = false;

  // ═══════════════════════════════════════════════════════════
  // 🔧 دەستپێکردن
  // ═══════════════════════════════════════════════════════════
  static Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  // ═══════════════════════════════════════════════════════════
  // 🎤 تۆمارکردن
  // ═══════════════════════════════════════════════════════════

  /// ✅ داواکردنی مۆڵەتی مایکرۆفۆن
  static Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      return false;
    }
  }

  /// ✅ دەستپێکردنی تۆمارکردن
  static Future<String?> startRecording() async {
    try {
      await _ensureInitialized();

      // ✅ پشکنینی ئەگەر پێشتر دەستیپێکردووە
      if (_isRecording) {
        debugPrint('⚠️ پێشتر تۆمارکردن دەستیپێکردووە');
        return null;
      }

      // پشکنینی مۆڵەت
      if (!await requestPermission()) {
        debugPrint('❌ مۆڵەتی مایکرۆفۆن ڕەتکرایەوە');
        return null;
      }

      // پشکنینی مایکرۆفۆن
      if (!await _recorder.hasPermission()) {
        debugPrint('❌ مایکرۆفۆن بەردەست نییە');
        return null;
      }

      // دروستکردنی فایلی کاتی
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/complaint_voice_$timestamp.m4a';

      // دەستپێکردن
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _isRecording = true;
      debugPrint('🎤 تۆمارکردن دەستیپێکرد: $path');
      return path;
    } catch (e) {
      debugPrint('❌ هەڵە لە دەستپێکردنی تۆمارکردن: $e');
      _isRecording = false;
      return null;
    }
  }

  /// ✅ وەستاندنی تۆمارکردن
  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        debugPrint('⚠️ تۆمارکردن دەستیپێنەکردووە');
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;
      debugPrint('⏹ تۆمارکردن وەستا: $path');
      return path;
    } catch (e) {
      debugPrint('❌ هەڵە لە وەستاندن: $e');
      _isRecording = false;
      return null;
    }
  }

  /// ✅ ئایا تۆمارکردن بەردەوامە؟
  static Future<bool> isRecording() async {
    try {
      return await _recorder.isRecording();
    } catch (e) {
      debugPrint('❌ isRecording error: $e');
      return false;
    }
  }

  /// ✅ هەڵوەشاندنەوە — ⚠️ dispose نەکە بۆ ئەوەی دووبارە بەکاربهێنرێت
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
      }
      debugPrint('🚫 تۆمارکردن هەڵوەشێنرایەوە');
    } catch (e) {
      debugPrint('❌ هەڵە لە هەڵوەشاندنەوە: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ☁️ بارکردن بۆ Supabase
  // ═══════════════════════════════════════════════════════════

  /// ✅ بارکردنی دەنگ بۆ Supabase Storage
  static Future<String?> uploadAudio(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ فایل نەدۆزرایەوە: $filePath');
        return null;
      }

      // ✅ پشکنینی قەبارە
      final fileSize = await file.length();
      if (fileSize < 1000) {
        debugPrint('⚠️ فایلی دەنگ زۆر بچووکە: $fileSize bytes');
        return null;
      }

      if (fileSize > 10 * 1024 * 1024) {
        debugPrint('⚠️ فایلی دەنگ زۆر گەورەیە: $fileSize bytes');
        return null;
      }

      final bytes = await file.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voice_$timestamp.m4a';

      // بارکردن
      await Supabase.instance.client.storage
          .from('complaints') // ✅ ناوی Bucket
          .uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'audio/mp4',
          cacheControl: '3600',
        ),
      );

      // وەرگرتنی URL
      final url = Supabase.instance.client.storage
          .from('complaints')
          .getPublicUrl(fileName);

      debugPrint('✅ دەنگ بارکرا: $url');

      // ✅ پاککردنەوەی فایلی کاتی
      try {
        await file.delete();
      } catch (e) {
        debugPrint('⚠️ نەتوانرا فایلی کاتی بسڕدرێتەوە: $e');
      }

      return url;
    } catch (e) {
      debugPrint('❌ هەڵە لە بارکردنی دەنگ: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧹 پاککردنەوەی سەرچاوەکان
  // ═══════════════════════════════════════════════════════════

  /// ✅ پاککردنەوەی سەرچاوەکان — تەنها کاتێک ئەپ دادەخرێت
  static Future<void> dispose() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
      }
      await _recorder.dispose();
      _isInitialized = false;
      debugPrint('✅ AudioService disposed');
    } catch (e) {
      debugPrint('❌ dispose error: $e');
    }
  }
}