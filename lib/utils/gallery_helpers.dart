
/// 🔢 گۆڕینی ژمارە بۆ کوردی
String toLocalDigits(String input) {
  const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  for (int i = 0; i < en.length; i++) {
    input = input.replaceAll(en[i], ar[i]);
  }
  return input;
}

/// 📏 گۆڕینی قەبارەی فایل بۆ خوێندنەوەی مرۆڤ
String formatImageSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// ✅ پشکنینی URLی وێنە
bool isValidImageUrl(String url) {
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
}