// lib/utils/error_handler.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart';
import '../l10n/tr.dart';

/// ⚠️ بەڕێوەبردنی هەڵەکان
class ErrorHandler {
  ErrorHandler._();

  // ═══════════════════════════════════════════════════════════
  // 📝 getUserMessage
  // ═══════════════════════════════════════════════════════════
  static String getUserMessage(Object error) {
    // Supabase
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

    if (error is AuthException) return '⚠️ هەڵەی چوونەژوورەوە';

    if (error is StorageException) return '⚠️ هەڵەی فایل';

    // Network
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

  // ═══════════════════════════════════════════════════════════
  // ❌ showError
  // ═══════════════════════════════════════════════════════════
  static void showError(BuildContext context, Object error) {
    AppLogger.e('Error', error);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(getUserMessage(error)),
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

  // ═══════════════════════════════════════════════════════════
  // ✅ showSuccess
  // ═══════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════
  // ⚠️ showWarning
  // ═══════════════════════════════════════════════════════════
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