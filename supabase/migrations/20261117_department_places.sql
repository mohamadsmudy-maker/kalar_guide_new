-- 20261117 — Departments are picked from registered places (dukan) and
-- every department transaction keeps its requirements + fees.
--
-- Safe to run more than once. Only adds what is missing.

-- 1) Link a department to the place it was picked from.
--    text, so it works whether dukan.id is int, bigint or uuid.
alter table public.departments add column if not exists place_id   text;
alter table public.departments add column if not exists name_ar    text;
alter table public.departments add column if not exists name_en    text;
alter table public.departments add column if not exists phone      text;
alter table public.departments add column if not exists address    text;
alter table public.departments add column if not exists website    text;
alter table public.departments add column if not exists image      text;
alter table public.departments add column if not exists color      text default '#10B981';
alter table public.departments add column if not exists updated_at timestamptz default now();

-- one department per place
create unique index if not exists departments_place_id_key
  on public.departments (place_id) where place_id is not null;

-- 2) Columns the transaction editor writes and the citizen screen reads.
alter table public.department_services add column if not exists title_ku      text;
alter table public.department_services add column if not exists title_ar      text;
alter table public.department_services add column if not exists title_en      text;
alter table public.department_services add column if not exists description   text;
alter table public.department_services add column if not exists duration      text;
alter table public.department_services add column if not exists notes         text;
alter table public.department_services add column if not exists requirements  jsonb default '[]'::jsonb;
alter table public.department_services add column if not exists fees          jsonb default '[]'::jsonb;
alter table public.department_services add column if not exists is_active     boolean default true;
alter table public.department_services add column if not exists display_order int default 0;
alter table public.department_services add column if not exists updated_at    timestamptz default now();

-- 3) The old admin editor saved the required papers in "documents" while the
--    citizen screen reads "requirements". Copy them over once, where possible.
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'department_services'
               and column_name = 'documents') then
    begin
      execute $q$
        update public.department_services
           set requirements = to_jsonb(documents)
         where documents is not null
           and (requirements is null or requirements::text in ('[]', '{}', ''))
      $q$;
    exception when others then
      raise notice 'documents -> requirements copy skipped: %', sqlerrm;
    end;
  end if;
end $$;

-- make PostgREST see the new columns immediately
notify pgrst, 'reload schema';
