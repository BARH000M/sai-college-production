# Phase 3B Main local package — final validation

Target: `aeryusbrulqdxjdynwfh`. Source package only; deployment remains on hold.
This closeout supersedes the earlier reconciliation report's statements that
Phase 3B database tests and forward proposals were still outstanding. The
40-migration reconciliation was not repeated.

## Reviewed package

- Three ordered SQL proposals under `supabase/deployment/phase3b-main/`:
  atomic roles and legacy-writer lockdown, serialized teacher assignments,
  and verified student/parent linking. `rollback_hold.sql` is a separately
  approved emergency write hold, not an automatic rollback or forward step.
- Shared `manage-roles` handler and routed `school-admin` role operations;
  existing unrelated school operations are preserved.
- Invitations grant no roles, branch memberships or class assignments, never
  auto-confirm email and never delete an account after partial setup failure.
  React teacher onboarding reflects the invitation/pending-access contract.
- Synthetic SQL fixtures exercise captured Main schema/ACL/policy contracts.
  The local `main_baseline.sql` contains captured DDL, not production accounts
  or application rows. It is excluded from Git as production-derived metadata.
  Replaying on another machine requires that protected local fixture or an
  explicitly supplied `--catalog-dir` capture. Neither is a restore certificate.

## Final checks

All executable source was finalized before these checks, each run once:

| Check | Result |
| --- | --- |
| `npm run type-check` | PASS |
| `npm run lint` | PASS, zero warnings |
| `npm.cmd test --prefix web` | PASS, 88 tests, zero failed/skipped |
| Deno `test --allow-env --allow-read --allow-net supabase/functions/` | PASS, 7 tests |
| `python supabase/tests/phase3b-main/run_local.py` | PASS |

The initial PowerShell invocation of web tests did not launch because of its
script execution policy; `npm.cmd` launched the recorded test run. Deno used an
existing cached executable. Edge tests mock HTTP; no hosted mutation was sent.

PostgreSQL 17 created a new loopback-only cluster, cleared inherited PG/Supabase
environment settings, checked database and data_directory before SQL sessions,
and passed preservation, RLS, role/branch ACL, verified-link, atomic audit,
unsupported isolation and concurrent last-admin revocation checks. The run
`edd4e31c-cec2-445c-b822-884ecb685b1a` stopped its cluster successfully. No
`pgdata/postmaster.pid` remained in any Phase 3B test directory after the run.
No production database connection, deployment, history repair, role assignment
or user modification was performed during this closeout. This is evidence of
this task's actions, not an independent audit of other production activity.

Temporary evidence, browser profiles and local clusters remain intact under
ignored `/.tmp-*/`. Credentials, environment files, backups, downloaded catalog
JSON/DDL, downloaded source artifacts and generated outputs are excluded. The
unrelated local `mobile/pubspec.lock` dependency updates remain uncommitted.
Reviewed new files and changes contain no detected credential material or
production application rows; account fixture addresses use `example.test`.

## Deployment gates

The source package is ready for deployment review, not production execution.
Approval still requires a fresh protected recovery point and a verified restore
on an isolated Supabase-compatible target, including Storage bytes and Edge
configuration. This synthetic replay does not meet that recovery gate.

Plan one controlled write hold and coordinated SQL/Edge/client cutover; use
`PHASE3B_MUTATIONS_DISABLED=true` for role/provisioning/linking Edge mutations
while cutting over. Install proposals in numeric order only after approval;
never apply the historical migration directory or repair migration history.
Verify Auth invitation delivery, confirmed sign-in, actual hosted authorization
and React/Flutter user journeys before reopening writes. Flutter device and
live backend QA are not certified by these local suites.

Settings hardening remains a separate additive Main-compatible change; preserve
existing settings/audits and resolve the recorded HTTPS incompatibility.
External Auth ban/unconfirmation operations after a transaction commits can
still make the final administrator unusable and require an operational guard.
The earlier reconciliation report retains the broader missing-feature backlog.
