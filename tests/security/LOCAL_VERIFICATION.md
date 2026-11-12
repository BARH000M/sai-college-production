# Supabase and permission testing — not yet executed

Test in a disposable Supabase environment with test users covering all nine roles.
1. Cross-branch: branch A student/teacher/parent must not read branch B students, progress, invoices or files.
2. Cross-class: teacher of class A must not mutate class B homework, exams, attendance or grades.
3. Parent: unverified and unrelated child links MUST be denied; only verified links may read a child's permitted data.
4. Service functions: unauthenticated calls to `manage-roles` and `school-admin` privileged actions must get 401/403. A signed-in student cannot grant roles. A super admin may grant only allowed roles.
5. Media: one-time signed URLs expire; private `lesson-media` objects must be unavailable via unauthenticated public URLs. Test upload MIME and file-size restrictions.
6. Multi-role: additive permitted operations; do not bypass class/branch checks.
7. Offline: replay the same mutation ID twice; progress saved only once, and resume checkpoint must remain consistent.
8. Never test role isolation by editing real students or creating fake production enrollments.

Evidence required: authenticated test identity, expected result, actual result, timestamp, environment, response status, and associated audit log. None of these tests has been executed in this package.
