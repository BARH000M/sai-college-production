# RLS and security review
**Positive static observation:** 47/47 public base tables have RLS enabled. **NOT evidence of negative-role denial.** Policies for new modules include branch scoping and student/parent safeguards, but cross-branch and class tests were not executed.

Advisors: 2 mutable search_path library functions, 3 anon-callable SECURITY DEFINER public-admissions functions, 41 authenticated-callable SECURITY DEFINER functions, disabled leaked-password protection. An Edge Function with `verify_jwt:false` may still perform explicit identity/role checks: manual review of `manage-roles` and `school-admin` source found `auth.getUser(token)` and DB role checks. Need executable rejection tests and rate limiting; do not assume safe or exploitable from a flag alone.

Prioritize: (1) public admissions abuse/rate limiting, (2) grant/revoke account integrity, (3) cross-branch RLS, (4) signed media files, (5) secret scanning, (6) account deletion/child privacy. Advisors: https://supabase.com/dashboard/project/aeryusbrulqdxjdynwfh/database/security-advisor

No `security definer` grants changed in production by this report.
