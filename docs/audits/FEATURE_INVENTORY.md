# SAI V2 feature inventory and priorities
The statuses below refer to verified evidence, **not UI visibility**. `PARTIAL` means a schema or route exists but the end-to-end user journey has not passed. No feature below is marked COMPLETE without functional verification.

| Feature | Web | Mobile | DB | Security | Tests | Evidence | Priority |
|---|---|---|---|---|---|---|---|
| Authentication | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | NOT VERIFIED | AuthGate/Supabase Auth source present, no live role journeys | P0 |
| Nine roles and multi-role | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | role enum, user_roles, portal role map | P0 |
| Admissions | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | admissions_enquiries with 6 rows, RPCs/Edge Functions, web/tests | P1 |
| Classes and students | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | 4 classes and 12 students, protected routes | P1 |
| Attendance | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | attendance_sessions/records nonempty | P1 |
| Finances | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | fee tables exist but empty, grants/RPC advisor warnings | P0 |
| Library | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | library_items/loans both empty | P1 |
| Downloads/inventory/transport | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | 3 new shared tables, RLS on, zero records | P1 |
| Student portfolio/housing/certificates/alumni | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | 4 new shared tables, RLS on, zero records | P1 |
| CMS | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | cms_site_content, cms_news, cms_programs plus sai_cms_pages | P1 |
| System settings | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | 7 settings rows, audit trigger + policies | P1 |
| Courses, lessons | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | 20 published lessons | P0 |
| Vocabulary | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | 30 published vocabulary entries, 28 linked to lessons | P0 |
| Lesson 101 E2E | MISSING | MISSING | MISSING | NOT VERIFIED | MISSING | no title/position candidate, no media | P0 |
| Authentic audio/media | MISSING | NOT VERIFIED | MISSING | PARTIAL | MISSING | 0 media objects in one private bucket | P0 |
| Speech/scoring engine | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | MISSING | No configured-provider response was tested | P1 |
| Review/SRS & handwriting | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | NOT VERIFIED | navigation exists; real algorithm/persistence unverified | P1 |
| Offline sync | NOT VERIFIED | NOT VERIFIED | MISSING | NOT VERIFIED | MISSING | no verified idempotent offline replay | P0 |
| Arabic/EN/ZH accessibility | PARTIAL | PARTIAL | PARTIAL | NOT VERIFIED | NOT VERIFIED | Cairo/Noto resources, but Flutter lacks declared zh locale | P1 |
| Android release / iOS TestFlight | NOT VERIFIED | NOT VERIFIED | N/A | NOT VERIFIED | NOT VERIFIED | debug build scripts, iOS sources; no signed artifacts | P1 |

**Test discipline:** Source code or a table existing is not proof of completion. Do not mark anything COMPLETE until a named user journey has an actual PASS result and evidence.
