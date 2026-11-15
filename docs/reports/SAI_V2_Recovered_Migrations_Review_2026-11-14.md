# Recovered Production migrations compared with V2

Read-only comparison of the three recovered SQL files with the 33-file V2
chain through protected admission status events. No recovery, source overwrite,
ledger repair, hosted query, or deployment was performed in this closeout.
The recovered SQL describes historical intent; it does not prove current hosted
schema or policy state.

| Recovered migration | Difference from V2 | Decision |
| --- | --- | --- |
| `20261110172940_sai_system_settings_shared_20261110.sql` | Creates `sai_system_settings`, its audit table, allowlisted nonsecret keys, value limits, stamp/audit triggers and role policies. None of these tables is created by V2's current chain. Mobile settings already queries the table. | Retain as review evidence; plan a new forward migration with settings-specific authorization tests. Do not copy into the historical V2 chain. |
| `20261110173339_sai_unified_modules_web_mobile_secure.sql` | Adds eight branch-scoped `sai_*` module tables, three public trigger functions, per-module RLS, student/branch guards and a CMS slug index. These objects are absent from V2 migrations; mobile's registry references them. | Separate next milestone: reconcile each client contract and role matrix, then author forward migrations and negative tests. This is a feature gap, not an admissions prerequisite. |
| `20261110173506_sai_unified_module_realtime.sql` | Adds the eight module tables to `supabase_realtime`; explicitly fails without that publication. V2 does not create those tables/publication. | Requires verified module DDL and actual target publication configuration first. Never apply alone. |

V2 `020` supplies `cms_programs`, `cms_news`, `cms_site_content` and private helper
prerequisites. Recovered `sai_cms_pages` is a distinct, branch-scoped CMS contract;
it does not replace these tables. V2 `022`–`029` consolidate and restrict helper
execution. Recovered policies use private helper names already supplied by V2,
but that shared spelling does not prove equivalent access semantics or deployment
ordering. Earlier recovered numbered migrations stop at `014` and omit V2 finance
`007`; the recovered set is not a substitute for V2's chain.

Security details needing focused review before adopting recovered DDL:

- Settings grants no DELETE to browser roles. Only super admins write; admins
  read a subset of categories. Audit reads are super-admin-only. Keep those
  restrictions and never store secrets in settings values.
- Module write roles differ: downloads/CMS include content editors, inventory
  includes accountants, transport/housing/certificates/alumni include receptionists,
  portfolios write through branch admins. Verify each role and cross-branch case.
- Student-specific reads join student/parent ownership; parent links require
  `verified_at`. V2 now guards account and parent linking through authorized RPCs.
  Regression tests must cover unverified links and changed student branches.
- Published `sai_cms_pages` are anonymously readable. Downloads are published to
  eligible authenticated users, not anonymous users. Preserve the distinction.
- Public trigger functions revoke browser execution, but definition privileges,
  default grants, trigger provenance, and audit forgery deserve dedicated tests.
  Their `audit_logs` entries are untrusted and must never feed admission history.
- Realtime requires an existing publication and table SELECT policies; adding a
  publication does not itself authorize rows. Test tenant and role visibility.

Suggested next milestone: settings and unified-module schema reconciliation,
starting with a reviewed client/table/role matrix and forward migration design.
Admissions security migrations remain unchanged.

## Compared evidence fingerprints

- `20261110172940_sai_system_settings_shared_20261110.sql`: SHA-256 `a07a5500870ca044dd6dda230462178ba46907e53ab2222b04065a171bb6d8f7`
- `20261110173339_sai_unified_modules_web_mobile_secure.sql`: SHA-256 `2be6ea1b7429abf3af653f6f029a6b7203d21aa35717af1e244168eea50d3f37`
- `20261110173506_sai_unified_module_realtime.sql`: SHA-256 `d40ef4d3f9a6adb9d0580a50697ee86e407fdb9da56d249adc1b3f0975e4cf17`
