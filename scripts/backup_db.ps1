# پاشەکەوتی داتابەیسی Supabase بۆ فایلی SQL.
# بەکارهێنان:
#   $env:DATABASE_URL = "postgresql://postgres:پاسۆرد@db.xxxx.supabase.co:5432/postgres"
#   .\scripts\backup_db.ps1
# پاسۆرد هەرگیز لەناو ئەم فایلەدا مەنووسە (دەچێتە git).
$ErrorActionPreference = "Stop"

if (-not $env:DATABASE_URL) {
    Write-Host "❌ DATABASE_URL دانەنراوە. بڕوانە docs/BACKUP.md" -ForegroundColor Red
    exit 1
}
if (-not (Get-Command pg_dump -ErrorAction SilentlyContinue)) {
    Write-Host "❌ pg_dump نەدۆزرایەوە. PostgreSQL client دابمەزرێنە (postgresql.org/download)." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path backups | Out-Null
$file = "backups/kalar-$(Get-Date -Format 'yyyy-MM-dd-HHmm').sql"

# تەنها پێکهاتەی public (ناوەکانی auth/storage ی Supabase لێرە ناگیرێن)
pg_dump --no-owner --no-privileges --schema=public --file=$file $env:DATABASE_URL
if ($LASTEXITCODE -ne 0) { Write-Host "❌ pg_dump شکستی هێنا" -ForegroundColor Red; exit 1 }

Write-Host "✅ پاشەکەوت کرا: $file" -ForegroundColor Green
Write-Host "⚠️ ئەم فایلە پاسۆردی هاشکراو و داتای کەسی تێدایە — بڵاوی مەکەرەوە." -ForegroundColor Yellow
