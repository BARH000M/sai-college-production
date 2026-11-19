# SEC-01 Secret Exposure Report

Date: 2026-11-19. **No production private credential literal was confirmed in the scanned text/history/public-artifact signatures. This bounded negative result is not exhaustive clearance.** Signing-material ACL exposure F10 is distinct from plaintext-secret disclosure. No rotation/revocation performed.

## Scan scope

32,436 workspace text files, including hidden/vendor/local paths; 3,283 reachable local Git blobs, across 230 locally reachable commits; repository not shallow. Workspace exclusions: 65 unreadable entries, 51,966 binary files, 94 files >5MB. Git binary/large exclusions: 476 blobs. No remote-ref fetch, unreachable/reflog-object scan or binary browser-session forensic scan.

Patterns: private PEM markers, Supabase secret prefixes, GitHub/AWS key forms, JWT claim classification and quoted credential assignments. Arbitrary/encoded/unquoted formats and compiled/split AOT strings may evade this method. Exact methods/results: E06-E08 and E12-E15.

| Category | Result | Redacted evidence / limits |
|---|---|---|
| Hardcoded administrators / default passwords | UNVERIFIED beyond scan | No confirmed production literal; active matches were UI labels or mocked tests, not hosted-account evidence |
| Supabase publishable/anon configuration | PASS for type classification | Selected configs use publishable or expected-ref legacy anon types; public client config is not a private credential leak. No signatures/project ownership certified |
| Service-role / private secret keys | PASS for scanned signatures | No confirmed actual client/source/history literal. Server Deno.env.get references are variable lookups. Mock service credentials are fabricated values |
| DB passwords / JWT signing / arbitrary API secrets | UNVERIFIED beyond signatures | No confirmed private literal; excluded/encoded surfaces not cleared |
| Android signing material | FAIL / P2 F10 | Ignored local yemen-sai-release.jks has broad inherited read/modify access; no password read, guessing, cracking or private-key export |
| Firebase / private certificates | UNVERIFIED beyond inventory | No current actual tracked Firebase service file/private certificate matched. App-public Firebase config would need separate classification if present |
| Auth access/refresh session protection | FAIL / P2 F05 | Flutter uses unencrypted preferences; no actual token value read. Browser SDK session persistence is JS-readable; runtime impact unverified |
| APK credentials | PASS for signature scope | No confirmed private secret; Debug kernel delimiter constants have zero strict base64-valid PEM blocks. AOT recovery incomplete |
| Historical browser/cache objects | UNVERIFIED | Deleted browser-cache paths occur in reachable Git objects; no current tracked browser profile. Binary/session residue not cleared |
| Published website configuration | FAIL for identity / F01 | Supabase client targets a third project. Public publishable key type is not proof of secret exposure |
| Retired Preview configuration | PASS for quarantine | External private backup and original copy hash/ACL verified; original absent; E02 |

Mock test credentials point to .test/.invalid/controlled clients and were not tried against production. No administrator account or password was tested, so absence of live default accounts remains UNVERIFIED.

## Credential handling

Remote catalogs did not request credential material or application records. One intentionally public publishable-key value appeared in tool output after a minified-string redactor failed; no private credential was disclosed and no key value is repeated here. Corrected subsequent context output redacted key patterns first. Do not infer a need to rotate private credentials from public-key visibility alone.

Current sensitive tracked-path check found examples, not actual env/keystore/private certificate files. Ignore rules reduce accidental additions but do not clear history. Local public anon configuration in a generated web bundle is expected, not a secret finding.

## Recommended next work

Prioritize F10 signing custody and F05 secure session storage under approved SEC-02 implementation. Expand private forensic/dedicated secret scanning to unreadable, large, binary and unreachable-history surfaces with controlled evidence handling. If a real private exposure is confirmed, seek explicit incident/rotation authorization. No deletion, history rewriting, key rotation or removal is part of SEC-01.
