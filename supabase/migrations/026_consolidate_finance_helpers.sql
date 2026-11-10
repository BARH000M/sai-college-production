-- 026 — Consolidate the finance read helpers (same oracle class as 022/025)
--
-- Discovered while auditing the remaining public RPCs: six finance policies were
-- still resolving to helpers in the `public` schema, unqualified:
--
--   fee_assignments_read   sai_finance_can_read_student(student_id, branch_id)
--   fee_payments_read      sai_finance_can_read_student(a.student_id, a.branch_id)
--   fee_waivers_read       sai_finance_can_read_student(a.student_id, a.branch_id)
--   fee_refunds_read       sai_finance_staff(branch_id, ARRAY['accountant'])
--   finance_audit_read     sai_finance_staff(branch_id, ARRAY['accountant'])
--   fee_groups_read        sai_finance_staff(branch_id, ARRAY['admin','accountant','receptionist'])
--
-- Because the names were unqualified, resolution depended on search_path, and
-- public.sai_finance_staff itself was invoker-mode calling public.sai_security_*.
-- That is the same drift that 022/025 fixed for security and learning. This
-- migration gives finance the same shape:
--
--   * one implementation per helper, in `private`, SECURITY DEFINER,
--     search_path pinned to pg_catalog, public, private;
--   * all six policies re-pointed to private.*;
--   * the public functions reduced to pure one-line delegators, so any legacy
--     call site keeps working but cannot diverge;
--   * the finance read helper no longer calls back into public.* at all
--     (the role/branch logic is inlined against user_roles/branch_memberships).
--
-- Applied live on the primary project. Idempotent.

create or replace function private.sai_finance_has_role(wanted text[])
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role::text = any(wanted)
  );
$function$;

create or replace function private.sai_finance_staff(wanted_branch uuid, wanted text[])
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select private.sai_finance_has_role(array['super_admin'])
    or (private.sai_finance_has_role(wanted) and private.sai_security_branch_member(wanted_branch));
$function$;

create or replace function private.sai_finance_can_read_student(wanted_student uuid, wanted_branch uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select
    exists (
      select 1 from public.user_roles r
      where r.user_id = (select auth.uid())
        and (
          r.role = 'super_admin'
          or (
            r.role in ('admin', 'accountant', 'receptionist')
            and exists (
              select 1 from public.branch_memberships m
              where m.user_id = (select auth.uid())
                and m.branch_id = wanted_branch and m.is_active
            )
          )
        )
    )
    or exists (
      select 1 from public.students s
      where s.id = wanted_student
        and (
          (
            s.user_id = (select auth.uid())
            and exists (
              select 1 from public.user_roles r
              where r.user_id = (select auth.uid()) and r.role = 'student'
            )
          )
          or (
            exists (
              select 1 from public.user_roles r
              where r.user_id = (select auth.uid()) and r.role = 'parent'
            )
            and exists (
              select 1 from public.parent_student_links l
              where l.student_id = s.id
                and l.parent_user_id = (select auth.uid())
                and l.verified_at is not null
            )
          )
        )
    );
$function$;

-- Public layer: pure delegators, no logic of their own.
create or replace function public.sai_finance_has_role(wanted text[])
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select private.sai_finance_has_role(wanted);
$function$;

create or replace function public.sai_finance_staff(wanted_branch uuid, wanted text[])
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select private.sai_finance_staff(wanted_branch, wanted);
$function$;

create or replace function public.sai_finance_can_read_student(wanted_student uuid, wanted_branch uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select private.sai_finance_can_read_student(wanted_student, wanted_branch);
$function$;

-- Re-point the six policies. Only the schema prefix changes.
alter policy fee_assignments_read on public.fee_assignments
  using (private.sai_finance_can_read_student(student_id, branch_id));

alter policy fee_payments_read on public.fee_payments
  using (
    exists (
      select 1 from public.fee_assignments a
      where a.id = fee_payments.assignment_id
        and private.sai_finance_can_read_student(a.student_id, a.branch_id)
    )
  );

alter policy fee_waivers_read on public.fee_waivers
  using (
    exists (
      select 1 from public.fee_assignments a
      where a.id = fee_waivers.assignment_id
        and private.sai_finance_can_read_student(a.student_id, a.branch_id)
    )
  );

alter policy fee_refunds_read on public.fee_refunds
  using (private.sai_finance_staff(branch_id, ARRAY['accountant'::text]));

alter policy finance_audit_read on public.finance_audit_log
  using (private.sai_finance_staff(branch_id, ARRAY['accountant'::text]));

alter policy fee_groups_read on public.fee_groups
  using (private.sai_finance_staff(branch_id, ARRAY['admin'::text, 'accountant'::text, 'receptionist'::text]));

-- Verification: both counts must be 0.
-- NOTE: pg_policies.qual is deparsed relative to the current search_path, so a
-- text match is unreliable. Use the dependency graph instead.
select
  (select count(*)
     from pg_depend d
     join pg_policy pol on pol.oid = d.objid
     join pg_proc p on p.oid = d.refobjid
     join pg_namespace pn on pn.oid = p.pronamespace
    where d.classid = 'pg_policy'::regclass
      and d.refclassid = 'pg_proc'::regclass
      and pn.nspname = 'public'
      and p.proname like 'sai\_%' escape '\') as policies_on_public_helpers,
  (select count(*)
     from pg_depend d
     join pg_proc src on src.oid = d.objid
     join pg_namespace sn on sn.oid = src.pronamespace
     join pg_proc ref on ref.oid = d.refobjid
     join pg_namespace rn on rn.oid = ref.pronamespace
    where d.classid = 'pg_proc'::regclass
      and d.refclassid = 'pg_proc'::regclass
      and sn.nspname = 'private'
      and rn.nspname = 'public'
      and ref.proname like 'sai\_%' escape '\') as private_helpers_calling_public;