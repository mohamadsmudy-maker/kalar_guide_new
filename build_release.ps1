# بەکارهێنان:  .\build_release.ps1          ← خێرا (clean ناکات)
#              .\build_release.ps1 -Clean   ← پاککردنەوەی تەواو پێش build
#              .\build_release.ps1 -NoObfuscate ← بێ شاردنەوەی ناوەکان (بۆ دۆزینەوەی کێشە)
param([switch]$Clean, [switch]$NoObfuscate)

$ErrorActionPreference = "Stop"

$SUPABASE_URL = "https://krqrhrqtmcpwpcsxkaql.supabase.co"
$SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtycXJocnF0bWNwd3Bjc3hrYXFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5NDg4MzIsImV4cCI6MjEwNDUyNDgzMn0.2jFpZfH3x9POPboN841XM8pu6uqErX6Viq5Luvgbldo"

# 🔵 Google Sign-In: «Web client ID» (docs/GOOGLE_LOGIN.md). بەتاڵ = دوگمەی Google پیشان نادرێت
$GOOGLE_WEB_CLIENT_ID = "346684844584-jdcmgk7j750utgfp7ellp2sorq6r710e.apps.googleusercontent.com"

# flutter clean تەنها کاتێک پێویستە ئەگەر build ی ناڕێک ببینی. لە Windows دا
# زۆرجار پۆشەی build قفڵە (Android Studio / ئێکسپلۆرەر / ئانتی‌ڤایرۆس) و
# هەڵەی «Failed to remove ...\build» دەدات، بۆیە بە بنەڕەت ناکرێت.
if ($Clean) {
    if (Test-Path "android\gradlew.bat") {
        Push-Location android
        .\gradlew.bat --stop | Out-Null   # daemon ی Gradle قفڵی build دەکات
        Pop-Location
    }
    flutter clean
}
flutter pub get

# 🔒 --obfuscate: ناوی کلاس و فەنکشنەکان دەگۆڕێت بۆ ناوی بێ مانا، بۆ ئەوەی ئەگەر
#    کەسێک APK ـەکە بکاتەوە، خوێندنەوەی کۆدەکە قورس بێت.
#    --split-debug-info: فایلی symbols لە پۆشەی symbols/<وەشان> هەڵدەگیرێت
#    (دەرەوەی build/ چونکە flutter clean دەیسڕێتەوە). بۆ خوێندنەوەی Crash
#    ـەکان پێویستە — هەر وەشانێک بەخۆی symbols ـی خۆی هەڵبگرە.
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$SYMBOLS_DIR = "symbols/$stamp"

$obf = @()
if (-not $NoObfuscate) { $obf = @("--obfuscate", "--split-debug-info=$SYMBOLS_DIR") }

flutter build apk --release --split-per-abi `
    @obf `
    --dart-define=SUPABASE_URL="$SUPABASE_URL" `
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" `
    --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID"

Write-Host "✅ تەواو بوو — symbols: $SYMBOLS_DIR (هەڵیبگرە)" -ForegroundColor Green
