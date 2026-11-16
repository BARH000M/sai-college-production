-- 030 — Restore immutable admissions fields after the broad 021 table grants.
--
-- Migration 004 deliberately granted only writable admission columns. The
-- table-level UPDATE/INSERT grants in 021 override those limits; retain the
-- existing RLS rules while restoring the original column-level boundary.

revoke insert, update on table public.admissions_enquiries from authenticated;

grant insert (
  branch_id, academic_session_id, applicant_full_name, guardian_name, phone,
  email, preferred_program, preferred_level, source, notes, assigned_to
) on public.admissions_enquiries to authenticated;

grant update (
  academic_session_id, applicant_full_name, guardian_name, phone, email,
  preferred_program, preferred_level, source, notes, status, assigned_to
) on public.admissions_enquiries to authenticated;
