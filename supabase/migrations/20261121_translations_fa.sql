-- زیادکردنی فارسی بۆ جەدوەلی وەرگێڕان
-- ئەمە چەکی (check constraint) ی lang لە text_translations گۆڕدەکات بۆ ئەوەی 'fa' قبووڵ بکات.

alter table public.text_translations
  drop constraint if exists text_translations_lang_check;

alter table public.text_translations
  add constraint text_translations_lang_check check (lang in ('en', 'ar', 'fa'));
