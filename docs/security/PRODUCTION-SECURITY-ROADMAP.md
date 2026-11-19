# Production Security Roadmap

Release decision: **NOT APPROVED on SEC-01 evidence.** This sequence is a proposal, not implementation or deployment authorization.

| Phase | Purpose | Exit evidence |
|---|---|---|
| SEC-01 / assessment completed within limits | Quarantine retired env, preserve work, inspect independent security workstreams and record missing assurance | Seven reports; E01-E28; 60 explicit control outcomes. Assessment completion does not mean all controls passed |
| SEC-02A / immediate | Resolve deployed identity F01 and branch boundary F02; prepare trusted audit/verified binding | Approved minimal changes, isolated authorization tests, reviewed deployment/migration targets; no third-project changes |
| SEC-02B | Session/signing custody, browser policies, repository/Auth hardening, action pins/library paths | F03-F12 closure evidence and regression tests; approved residual risks |
| SEC-03 / deployment assurance | Establish exact web/mobile/DB/RPC/Edge deployed-source parity | Catalog baseline and hashes; known Auth/Storage contract; correct backend and signed distribution artifact; no private client secrets |
| SEC-04 / authenticated privacy QA | Student A/B, verified/unverified parent, assigned/unassigned teacher, branch A/B admins, finance and super-admin boundaries | Controlled-account read/deny matrix; authorized isolated write tests; exam publication and finance/idempotency invariants |
| SEC-05 / recovery and release | Establish acceptable RPO/RTO, key custody and recovery response | Authorized isolated restore drill, operational runbooks, custody restore proof, owner risk sign-off and release decision |
| Ongoing | Detect drift, new advisories and access misuse | Reviewed dependency/action updates, secret scanning, required PR checks, artifact identity checks, access reviews, audit monitoring, periodic recovery drills |

Public publishable/anon keys are configuration; backend authorization protects records. Source guards/offline tests do not prove hosted enforcement. A valid APK signature proves integrity under a certificate, not approved ownership or distribution. Completed backups do not prove successful restoration. Authenticated definer warnings need semantic authorization review, not automatic severity assignment.

No fixes/deployments without explicit next-phase approval. Do not connect to retired or third backend, overwrite the staged relocation, weaken tests, copy production credentials into retired configuration or apply historical migrations without reconciliation. Keep local preview/mock/testing infrastructure intact.

See SECURITY-REMEDIATION-PLAN.md, SECURITY-CHECKLIST.md and SECURITY-EVIDENCE-MATRIX.md for ordered work, exact outcomes and evidence.
