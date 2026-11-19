# SEC-02 Prioritized Remediation Plan — awaiting implementation approval

Assessment: 60 checks; PASS32, FAIL12, BLOCKED3, UNVERIFIED13. Findings: P0 0, P1 2, P2 8, P3 2. No vulnerability fixes implemented; only explicitly authorized Preview quarantine completed.

Existing local SQL proposals must be reviewed against hosted state; their presence is not permission to apply them. Do not replay old migrations blindly.

| Order | Scope / owner | Concrete work to prepare | Release evidence |
|---|---|---|---|
| 1 | F01 / deployment owner | Establish domain/deployment provenance and exact source/commit; prepare authorized Production-only website artifact; do not alter third project | Reviewed deployment approval; public initializer/runtime targets authoritative backend; correct signed-in routes; no private client credentials |
| 2 | F02 / database authorization owner | Review branch-protection proposal; remove direct mutable tenant keys; tightly authorize atomic membership changes | Isolated two-branch admin self/other reassignment denials, legitimate super-admin path, old/new scope tests; explicit SQL deployment approval |
| 3 | F03/F04 / onboarding and DB owner | Trusted audit producers and verified student binding/replacement; preserve historical unverified audit labels | Isolated forged-event denial, genuine trigger audit, usable confirmed-account checks, FK/unique and replacement regressions |
| 4 | F05/F10 / mobile/signing owner | OS-backed session adapter and migration plan; private signing ACL/custody and managed recovery | Android/iOS migration/logout/refresh/backup tests; effective ACL and signing-artifact provenance; key-custody restore proof |
| 5 | F06/F07 / hosting owner | Tested CSP/frame-ancestors, HSTS; review MIME/referrer/permissions policies and external scripts | Browser compatibility, framing denial, domain HTTPS policy; no broken approved login/media/upload flows |
| 6 | F08/F11 / repository owner | Required reviews/checks for main, reviewed action SHA pins, controlled updates | Settings recheck, approved PR flow, verified bypass/recovery paths |
| 7 | F09/F12 / Auth/database owner | Enable compromised-password defense after impact review; qualify library invoker paths | Controlled Auth-account tests; isolated library behavior/RLS regression checks |
| 8 | QA/release/recovery owners | Reconcile migration inventory while preserving staged relocation; prove hosted exam/homework/role/mutation contracts; run controlled role matrix and recovery drill | Fully green tests, exact deployed-source parity, approved signed distribution artifact, student/parent/staff/finance/exam isolation, agreed RPO/RTO and successful authorized restore |

## Immediate release blockers

F01 deployed backend mismatch and F02 tenant escape are immediate blockers. P2 privacy/session/signing/browser/repository/Auth weaknesses require remediation or explicit documented risk acceptance. Missing hosted contracts, authenticated isolation/finance/exam evidence, artifact provenance, failed web inventory gate and untested recovery prevent approval.

## Approval boundary

Next phase recommendation: SEC-02A identity correction and authorization containment. Prepare minimal concrete changes and validation first; obtain explicit approval naming target systems before implementation/deployment. No automatic SQL, Auth settings, GitHub settings, ACL fix, credential rotation, third-project alteration, commit or push follows from this plan. Preserve local offline preview/mocks/tests and the existing staged SQL relocation.
