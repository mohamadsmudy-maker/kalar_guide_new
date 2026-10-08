import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart';   // ✅ ئەم import ـە زیاد بکە
import 'app_logger.dart';   // ✅ ئەم import ـە زیاد بکە

/// ⚠️ بەڕێوەبردنی هەڵەکان
class ErrorHandler {
  /// ✅ وەرگرتنی نامەی هەڵەی بەکارهێنەر-دۆستانە
  static String getUserMessage(Object error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '23505':
          return '⚠️ ئەم زانیارییە پێشتر هەیە';
        case '23503':
          return '⚠️ زانیاری پەیوەندیدار نەدۆزرایەوە';
        case '42P01':
          return '⚠️ تەیبڵ نەدۆزرایەوە';
        case 'PGRST116':
          return '⚠️ زانیاری نەدۆزرایەوە';
        default:
          return '⚠️ هەڵەی داتابەیس';
      }
    }

    if (error is AuthException) {
      return '⚠️ هەڵەی چوونەژوورەوە';
    }

    if (error is StorageException) {
      return '⚠️ هەڵەی فایل';
    }

    final errorStr = error.toString();

    if (errorStr.contains('SocketException') ||
        errorStr.contains('Connection')) {
      return '🌐 پەیوەندی ئینتەرنێت نییە';
    }

    if (errorStr.contains('TimeoutException')) {
      return '⏰ کاتەکە تێپەڕی — دووبارە هەوڵ بدە';
    }

    return '❌ هەڵەیەک ڕووی دا';
  }

  /// ✅ پیشاندانی هەڵە بە SnackBar
  static void showError(BuildContext context, Object error) {
    AppLogger.e('Error', error);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          getUserMessage(error),
          style: const TextStyle(fontFamily: 'Rabar'),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// ✅ پیشاندانی سەرکەوتن
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ $message',
          style: const TextStyle(fontFamily: 'Rabar'),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// ✅ پیشاندانی ئاگاداری
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚠️ $message',
          style: const TextStyle(fontFamily: 'Rabar'),
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}