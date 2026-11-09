# Release checklist — NO GO

All boxes are outstanding. A checked box must link to dated, access-controlled
evidence from the exact release and target. No database or restore test was
performed when this candidate was prepared.

## Before any future deployment

- [ ] Authenticate the actual MAIN project/tenant and deployment identity
      independently; control auto-deployment so original 005 cannot replay.
- [ ] Compare live catalogs, object bodies, trigger definitions, policies,
      effective privileges, extensions and applied bytes against the saved
      baseline; explain all drift, including MAIN-only admissions features.
- [ ] Review custom-GUC spoofing, direct DML, `sai_submit_application` JWT
      impersonation, nested calls/pool reuse and audit attribution with
      real effective API roles. Fix unsafe paths without disrupting website
      submissions. No current bypass is assumed exploitable or safe.
- [ ] Establish a supported, truthful history/convergence approach and an
      atomic independent runner/ledger with target verification and retry,
      crash, partial-commit and concurrency tests. This bundle has none.
- [ ] Review and sign hashes for the complete bundle, historical sources,
      fixture and test scripts. Rehearse exact bytes and executor privileges.
- [ ] Establish required CREATE ROLE, database/schema CREATE, REFERENCES,
      table ownership/policy creation, role SET/ADMIN, GRANT/ownership-transfer
      rights, schema protections and PG 16+ role membership behavior.
- [ ] Prove finance RLS/FORCE, browser denial, owner membership and function
      ACLs; test permissive-policy OR interactions with finance lock-column
      grants. Resolve business decisions on immutability, cross-branch
      integrity, idempotency, external payment and audit provenance.
- [ ] Create recent backup and **successfully restore and validate** it in a
      separately isolated compatible environment, including data, history,
      roles/ACLs, extensions, sequences, Storage bytes and integrations.
      Accept measured RPO/RTO; an untested archive is not recoverability.
- [ ] Execute all disposable tests, including authentic anon and authenticated
      admissions, active/inactive session and branch/assignee checks,
      attendance roles, parent/student visibility, finance payment/refund
      idempotency and cross-branch denials, RLS and effective permissions.
      Existing test fixtures may need adjustment for MAIN drift; never weaken
      security or use real personal data to make a test pass.
- [ ] Add and run missing concurrency, direct/indirect GUC and JWT abuse,
      `sai_submit_application`, PostgREST/connection-pooling, failure-injection
      and role-membership tests on production-equivalent disposable systems.
- [ ] Approve explicit ordering, stop points and rollback/compensation plans.
      Keep financial writes disabled until security and business acceptance.

## After a separately authorized future deployment

- [ ] Compare actual function bodies/ACLs and admissions triggers to their
      pre-release baseline; verify website submission and audit behavior using
      approved smoke procedures without exposing personal data.
- [ ] Verify attendance RLS/policies, finance ownership/FORCE RLS and role
      memberships, grants, RPCs, sequence behavior and effective API access.
- [ ] Verify truthful independent ledger records and Supabase history without
      inserting or repairing history; confirm automatic 005 replay remains
      prevented. Monitor errors, latency and external financial reconciliation.
- [ ] Record release outcome, complete evidence and incident contacts. A
      clean `verify.sql` alone does not satisfy these checks.
