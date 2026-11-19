# Security Checklist

Date: 2026-11-19. 60 defined audit checks: PASS 32, FAIL 12, UNVERIFIED 13, BLOCKED 3. Confirmed findings: P0 0, P1 2, P2 8, P3 2.

PASS covers only the stated tested condition. FAIL is a verified weakness. BLOCKED means a prerequisite/restriction prevents verification; UNVERIFIED means insufficient evidence. These are audit work units, not counts of every requirement in OWASP standards. A bounded negative scan or a source-only PASS does not clear deployment security.

| ID | Check | Result | Evidence | Scope / limitation |
|---|---|---|---|---|
| C01 | Repository and branch identity | PASS | E01 | Local main/origin match; deployment commit unknown |
| C02 | Retired environment backup hash | PASS | E02 | Original and both external copies match |
| C03 | Quarantine permissions / Git separation | PASS | E02 | Only current user and SYSTEM; outside repository |
| C04 | Local web Production target | PASS | E03 | Authorized URL and target guard |
| C05 | Local Flutter Production target | PASS | E03 | Hardcoded approved backend and live JSON |
| C06 | CLI / MCP Production target | PASS | E03 | Existing link and three MCP configs agree |
| C07 | Offline preview retained | PASS | E04 | Demo branch skips Supabase initialization |
| C08 | Published website backend identity | FAIL | F01/E05 | Third project in published Supabase initializer |
| C09 | Selected client public key types | PASS | E06 | Publishable/anon types only in selected configs |
| C10 | Workspace text secret signatures | PASS | E07 | No confirmed private literal within scanned scope; exclusions apply |
| C11 | Reachable Git text secret signatures | PASS | E07 | No confirmed private literal within scanned local blobs |
| C12 | Current tracked sensitive filenames | PASS | E08 | No actual env/keystore/private certificate matched |
| C13 | Git ignore rules | PASS | E08 | Sensitive environment/signing/session exclusions |
| C14 | GitHub scanning and push protection | PASS | E09 | Enabled; zero alerts returned |
| C15 | Main review/change protection | FAIL | F08/E09 | No branch protection or rulesets observed |
| C16 | Workflow token permissions | PASS | E10 | contents: read; inspected jobs checks-only |
| C17 | Workflow action immutability | FAIL | F11/E10 | Mutable action version tags |
| C18 | npm advisory checks | PASS | E11 | Zero known vulnerabilities in both lockfiles |
| C19 | Pub advisory checks | PASS | E11 | OSV no matches for 102 locked hosted packages |
| C20 | APK discovery / existing tools | PASS | E12 | Six paths, five unique hashes |
| C21 | Signed candidate signature integrity | PASS | E12 | apksigner passes; certificate ownership unknown |
| C22 | Signed APK debug flags / permissions | PASS | E12 | Not debuggable; no unnecessary dangerous permissions observed |
| C23 | APK component exposure | PASS | E12 | Providers/WebView not exported; profiler permission-gated |
| C24 | APK observed backend hosts | PASS | E12 | Authorized project in inspected APKs |
| C25 | APK private credential signatures | PASS | E12 | No confirmed private literal; AOT decoding incomplete |
| C26 | Distribution artifact provenance | UNVERIFIED | E12 | Mixed intermediates/Debug files; distributed APK unidentified |
| C27 | Signing file access | FAIL | F10/E13 | Keystore broad inherited Windows ACL |
| C28 | Mobile session encryption | FAIL | F05/E14 | SharedPreferences session adapter |
| C29 | Android session backup exclusions | PASS | E14 | Cloud and transfer exclusions; runtime not tested |
| C30 | Mobile source auth/role gate | PASS | E14 | SDK auth and fail-closed account roles |
| C31 | Device session lifecycle | UNVERIFIED | E14 | No device refresh/revocation tests |
| C32 | TLS bypass source search | PASS | E14 | No active badCertificateCallback/HttpOverrides bypass found |
| C33 | Runtime TLS / cleartext behavior | UNVERIFIED | E12/E14 | No traffic interception; targetSdk 36/no override observed |
| C34 | Deep-link takeover resistance | UNVERIFIED | E14 | Custom scheme; dynamic PKCE/state/OS behavior not tested |
| C35 | Release obfuscation / signing custody | UNVERIFIED | E12/E13 | No executed hardened release pipeline or custody restore proof |
| C36 | Student/finance export and cache lifecycle | UNVERIFIED | E15 | User-scoped pending finance requests; no residue inspection |
| C37 | Browser session storage assurance | UNVERIFIED | E15 | SDK persistence is JS-readable; runtime/XSS scenarios not tested |
| C38 | Unsafe HTML sink source search | PASS | E15 | No active direct sink matches; not complete XSS proof |
| C39 | Production CSP / framing policy | FAIL | F06/E16 | Absent headers/meta in observed response |
| C40 | Production HSTS | FAIL | F07/E16 | Absent in observed HTTPS response |
| C41 | Upload enforcement end-to-end | UNVERIFIED | E17 | Client/static policy checks only; no upload test |
| C42 | Public source-map exposure | UNVERIFIED | E05/E15 | Local maps enabled; main map request rejected; bounded public scan |
| C43 | Public table RLS flags | PASS | E18 | 47/47 ordinary public tables enabled |
| C44 | Untrusted schema CREATE privileges | PASS | E18 | Denied in public/private; private anon USAGE denied |
| C45 | Branch reassignment boundary | FAIL | F02/E19 | Effective policy/grants permit reassignment |
| C46 | Generic audit integrity | FAIL | F03/E20 | Column INSERT and own-actor policy |
| C47 | Verified student account binding | FAIL | F04/E21 | Direct user_id writes; no identity guard |
| C48 | Direct role and parent-link writes | PASS | E22 | No authenticated direct write grants observed |
| C49 | Student / parent multi-user isolation | UNVERIFIED | E22 | Scoped predicates exist; no real-role proof; F02 applies |
| C50 | Finance isolation / transaction invariants | UNVERIFIED | E23 | Policies/selected guards inspected; no role/refund/idempotency proof |
| C51 | Examination hosted controls | BLOCKED | E24 | No hosted exam/result tables |
| C52 | Storage bucket visibility | PASS | E17 | One private bucket with limits/allowlist |
| C53 | Definer paths / anonymous RPC surface | PASS | E25 | 85 fixed paths; no public definer anon execute |
| C54 | Library invoker search paths | FAIL | F12/E25 | Two functions missing fixed paths |
| C55 | Privileged RPC full authorization | UNVERIFIED | E25 | Authenticated definers require semantic/role verification |
| C56 | Compromised-password rejection | FAIL | F09/E26 | Advisor disabled control |
| C57 | Super Admin MFA / recovery assurance | UNVERIFIED | E26 | No enrollment/aal2/last-usable-admin proof |
| C58 | Physical backup availability | PASS | E27 | Eight completed backups listed |
| C59 | Restore drill and RPO/RTO | BLOCKED | E27 | Not performed under read-only scope |
| C60 | Current validation gate | BLOCKED | E28 | 4/4 identity; 111/112 web; inventory failure preserved |

Evidence details: [SECURITY-EVIDENCE-MATRIX.md](SECURITY-EVIDENCE-MATRIX.md). Confirmed vulnerabilities and recommendations: [SEC-01-AUDIT-REPORT.md](SEC-01-AUDIT-REPORT.md). Release remains NOT APPROVED.
