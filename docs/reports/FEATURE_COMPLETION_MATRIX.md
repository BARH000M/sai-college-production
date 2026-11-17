# Feature completion matrix
See `docs/audits/FEATURE_INVENTORY.md` for 20 tracked features and evidence. No multi-role workflow is marked COMPLETE because a current 9-role end-to-end run was not available.

| Phase | Status | Evidence | Exit condition |
|---|---|---|---|
| 1 Audit | PARTIAL | GitHub tree, live DB metadata, local logs | all baseline commands and environment inventory |
| 2 Design | PARTIAL | Cairo/Noto assets, additive CSS patch | responsive screenshots + accessibility review |
| 3 Database | PARTIAL | 47 RLS tables, migration drift | migrations reconciled, positive/negative tests |
| 3C Shared identity and profile | LOCAL COMPLETE | Main-only web/mobile/MCP config; `web/tests/profile-contact.test.cjs`, `mobile/test/profile_contact_test.dart`, `supabase/tests/profile_contact_behavior.sql` (9-role own-contact, immutable identity/email/time, anonymous denial); 91 web + 53 Flutter tests pass 2026-11-17 | approved deployment of `supabase/deployment/phase3c-main/001_own_contact_validation.sql` proposal to Main |
| 4A Examinations and results (first workflow) | LOCAL COMPLETE | Additive proposal `supabase/deployment/phase4a-examinations/001_examinations.sql` (exams + exam_results, draft→marks_entry→review→published state machine, grade bands, RLS); isolated-cluster behavior test `supabase/tests/examinations_behavior.sql` PASS; web `src/portal/pages/Examinations.tsx` + printable sheets; Flutter `mobile/lib/ui/exams_screen.dart`; 98 web + 58 Flutter tests, lint, type-check, analyze pass 2026-11-17 | approved deployment of the 001 proposal to Main, then hosted acceptance run |
| 4 Lesson 101 | MISSING | no 101 candidate or media | approved content + end-to-end checkpoint/resume |
| 5 Learning engines | PARTIAL/NOT VERIFIED | course/vocabulary models | real provider and engine tests |
| 6 Nine roles | PARTIAL | role enum/nav exists; 9-role SQL behavior test for profiles own-contact | complete 9-role user-journey matrix |
| 7 Security | PARTIAL | Supabase advisors WARN; profile contact trigger validates name/phone/locale server-side (proposal) | zero critical unresolved security findings |
| 8 Automation | PARTIAL | mobile-ci and web/tests; `tests/main-integration.test.mjs` added to web-ci push/PR paths | web/mobile/E2E/database CI passing |
| 9 Deployment | BLOCKED | no Hostinger write credentials, GitHub 403 | authorized reviewed deployment |

Phase 3C note: completion is evidenced locally only. The SQL in `supabase/deployment/phase3c-main/` is an additive proposal and has NOT been executed against Main; no production migration is approved.
