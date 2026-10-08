# 🔒 Security Guide

## ✅ کێشەکانی چارەسەرکراو

### ١. Plaintext Password Compare
- ✅ چارەسەرکرا
- ✅ تەنها لە Debug Mode کار دەکات

### ٢. Rate Limiting
- ✅ ٥ هەوڵ → بلۆک بۆ ١٥ خولەک

### ٣. AI API Key
- ✅ گواسترایەوە بۆ Supabase Edge Function

### ٤. Storage Policies
- ✅ RLS چالاک لە هەموو Buckets

### ٥. Error Handling
- ✅ ErrorHandler ی تەواو

---

## 🎯 Best Practices

### ١. Password Security
```dart
// ✅ هەمیشە SHA-256 + Salt بەکاربهێنە
final hash = PasswordHasher.hash(password);