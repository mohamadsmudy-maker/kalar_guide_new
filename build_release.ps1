
$ErrorActionPreference = "Stop"

$SUPABASE_URL = "https://krqrhrqtmcpwpcsxkaql.supabase.co"
$SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtycXJocnF0bWNwd3Bjc3hrYXFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5NDg4MzIsImV4cCI6MjEwNDUyNDgzMn0.2jFpZfH3x9POPboN841XM8pu6uqErX6Viq5Luvgbldo"

# 🔵 Google Sign-In: «Web client ID» (docs/GOOGLE_LOGIN.md). بەتاڵ = دوگمەی Google پیشان نادرێت
$GOOGLE_WEB_CLIENT_ID = ""

flutter clean
flutter pub get

flutter build apk --release --split-per-abi `
    --dart-define=SUPABASE_URL="$SUPABASE_URL" `
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" `
    --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID"

Write-Host "✅ تەواو بوو" -ForegroundColor Green
