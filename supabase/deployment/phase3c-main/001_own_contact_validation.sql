-- PROPOSAL ONLY: additive Main-compatible validation; do not replay migrations.
-- Existing profiles own-row RLS and column grants remain authoritative.
begin;

do $$
begin
  if not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname='profiles' and c.relrowsecurity) then
    raise exception 'Expected Main profiles table with RLS enabled';
  end if;
  if has_table_privilege('authenticated','public.profiles','UPDATE')
      or has_column_privilege('authenticated','public.profiles','email','UPDATE')
      or has_column_privilege('authenticated','public.profiles','id','UPDATE') then
    raise exception 'Unexpected broad profile privileges; review before installing';
  end if;
end $$;

create or replace function public.sai_profiles_validate_contact()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_digits integer;
begin
  if new.full_name is distinct from old.full_name then
    new.full_name := btrim(new.full_name);
    if new.full_name is null or char_length(new.full_name) not between 2 and 120
        or new.full_name ~ '[[:cntrl:]]' then
      raise exception using errcode='22023', message='Invalid contact name';
    end if;
  end if;
  if new.phone is distinct from old.phone then
    new.phone := nullif(btrim(new.phone), '');
    v_digits := char_length(regexp_replace(coalesce(new.phone,''),'[^0-9]','','g'));
    if new.phone is not null and (new.phone !~ '^[+0-9][0-9 ()-]{5,31}$'
        or v_digits not between 6 and 20) then
      raise exception using errcode='22023', message='Invalid contact phone';
    end if;
  end if;
  if new.preferred_locale is distinct from old.preferred_locale
      and (new.preferred_locale is null or new.preferred_locale not in ('ar','en')) then
    raise exception using errcode='22023', message='Unsupported contact locale';
  end if;
  new.updated_at := pg_catalog.now();
  return new;
end $$;
revoke all on function public.sai_profiles_validate_contact() from public,anon,authenticated;

-- Only update-time validation; no existing rows are changed or backfilled.
-- Account creation, Auth email, role and enrollment contracts are untouched.
create trigger sai_profiles_contact_guard
before update of full_name,phone,preferred_locale on public.profiles
for each row execute function public.sai_profiles_validate_contact();
commit;
