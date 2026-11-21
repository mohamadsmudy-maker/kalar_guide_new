-- ═══════════════════════════════════════════════════════════════════
-- 📢 Kalar Guide — sponsored slides can open a news item
-- ═══════════════════════════════════════════════════════════════════
-- Safe to run more than once. Needs migration 28.
-- action_type = 'news' + action_value = ناسنامەی هەواڵەکە.
-- ═══════════════════════════════════════════════════════════════════

alter table public.sponsored_slides drop constraint if exists sponsored_slides_action_type_check;
alter table public.sponsored_slides add constraint sponsored_slides_action_type_check
  check (action_type in ('none', 'phone', 'whatsapp', 'url', 'place', 'news'));
