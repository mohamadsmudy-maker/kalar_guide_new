# 💾 پاشەکەوتی داتابەیس (Supabase)

پلانی بەخۆڕایی Supabase پاشەکەوتی ڕۆژانەی تەواوی نییە، بۆیە **هەفتانە خۆت export بکە**.

## ڕێگای ١ — ئاسان (بێ هیچ بەرنامەیەک)

Supabase ← **Table Editor** ← هەر خشتەیەک ← **Export** ← CSV.
خشتە گرنگەکان: `dukan`، `news`، `app_users`، `complaints`، `events`، `emergency_services`،
`main_categories`، `sub_categories`، `neighborhoods`، `gallery`، `videos`، `text_translations`.
> `app_users` پاسۆردی هاشکراوی تێدایە — فایلەکە هەرگیز بڵاو مەکەرەوە.

## ڕێگای ٢ — تەواو (SQL dump)

پێویستی بە PostgreSQL client هەیە (`pg_dump`). Supabase ← **Project Settings ← Database ←
Connection string (URI)** کۆپی بکە و پاسۆردی داتابەیس تێدا دابنێ.

```powershell
$env:DATABASE_URL = "postgresql://postgres:پاسۆرد@db.xxxx.supabase.co:5432/postgres"
.\scripts\backup_db.ps1
```

فایلەکە لە `backups\kalar-<بەروار>.sql` دروست دەبێت. پۆشەی `backups\` لە git دا نییە.

## چی هەڵبگریت

- فایلی پاشەکەوت: لە **کۆمپیوتەر + فلاش/درایڤی تایبەت** (نەک تەنها یەک شوێن).
- وێنەکانی Storage (`gallery_images` و هتد): Supabase ← **Storage** ← دایبگرە، ئەگەر گرنگن.

## گەڕاندنەوە

```powershell
psql "$env:DATABASE_URL" -f backups\kalar-2026-11-12.sql
```
(لەسەر پڕۆژەیەکی **نوێ**، نەک ئەو پڕۆژەیەی کە دەیەوێت ئەوەی ئێستا بسڕێتەوە.)
