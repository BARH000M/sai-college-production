# Build and deployment status
| Target | Result | Evidence |
|---|---|---|
| GitHub main | NO REMOTE WRITE | create branch returned 403; original main untouched by tool |
| Supabase live DB | READ ONLY | catalog + advisors + Edge Function source inspected; no writes |
| Root React production | NOT RE-RUN | user's earlier Vite build succeeded; later root typecheck had errors |
| Secondary web/ | NOT RUN | package/test scripts exist; run in Windows/CI |
| Android debug APK | NOT BUILT HERE | previous user build halted at Flutter test |
| Signed AAB | NOT BUILT | signing materials not available; do not invent |
| iOS IPA/TestFlight | NOT BUILT | macOS/cloud signing access not provided |
| sai-academic.com Hostinger | NOT DEPLOYED | live hosting access and approval absent |

Rollback: Git diff, out-of-repo installer backup, original remote commit SHA. No database rollback needed because there were no DB writes. Production host deployment requires explicit confirmation and validated build.
