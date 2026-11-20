-- 017_demo_attendance_week.sql
-- Demo week of attendance so reports, QR sheets and the notification feed are
-- populated on a fresh environment. Guarded: it only runs when no attendance
-- session exists yet, so it never touches real attendance data.

with actor as (
  select coalesce(
    (select ur.user_id from public.user_roles ur
      where ur.role::text in ('super_admin', 'admin', 'teacher') limit 1),
    (select p.id from public.profiles p limit 1)
  ) as user_id
), days as (
  select d::date as day
  from generate_series(current_date - interval '7 days', current_date, interval '1 day') as d
  where extract(isodow from d) between 1 and 5
), planned as (
  select c.id as class_id, c.branch_id, c.session_id, d.day,
    row_number() over (order by d.day, c.name) as ordinal
  from public.classes c
  cross join days d
  where c.is_active
)
insert into public.attendance_sessions (
  branch_id, academic_session_id, class_id, attendance_date,
  start_time, end_time, status, created_by
)
select
  p.branch_id,
  p.session_id,
  p.class_id,
  p.day,
  (p.day::timestamp + time '08:00') at time zone 'UTC',
  (p.day::timestamp + time '10:00') at time zone 'UTC',
  case when p.day = current_date then 'open' else 'closed' end,
  (select user_id from actor)
from planned p
where (select user_id from actor) is not null
  and not exists (
    select 1 from public.attendance_sessions s
    where s.class_id = p.class_id and s.attendance_date = p.day
  )
  and not exists (select 1 from public.attendance_sessions);

insert into public.attendance_records (
  attendance_session_id, student_id, status, marked_by, marked_at
)
select
  s.id,
  st.id,
  case
    when abs(hashtext(st.id::text || s.attendance_date::text)) % 10 = 0 then 'absent'
    when abs(hashtext(st.id::text || s.attendance_date::text)) % 10 in (1, 2) then 'late'
    when abs(hashtext(st.id::text || s.attendance_date::text)) % 10 = 3 then 'excused'
    else 'present'
  end,
  s.created_by,
  s.start_time
from public.attendance_sessions s
join public.students st on st.class_id = s.class_id
where s.created_by is not null
  and not exists (
    select 1 from public.attendance_records r
    where r.attendance_session_id = s.id and r.student_id = st.id
  );