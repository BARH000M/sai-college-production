# Admissions Edge Function security and local checks

`admission-tracking`, `admission-notify`, `link-student-account` and
`provision-learning-account` and `manage-roles` pin the already validated Supabase JS version
2.119.0. `deno.lock` records remote integrity. Check all function entry points
with `deno check supabase/functions/*/index.ts` (expand the glob in PowerShell),
then run `deno test --allow-env supabase/functions/`. Tests mock fetch/serve;
they need no service credentials, live network requests, or PostgreSQL server.

## IP trust boundary

Public tracking and token/submission emails fail closed (503) unless
`ADMISSIONS_TRUSTED_IP_HEADER` is configured to `cf-connecting-ip` or
`x-sai-client-ip`. No header is trusted by default. No X-Forwarded-For or X-Real-IP
fallback is permitted. The parser requires one valid IPv4/IPv6 literal and
canonicalizes IPv6 spelling before the HMAC rate-limit key is calculated.

Set that environment variable only after the deployment operator verifies that
ingress overwrites the selected header on every supported URL/path and that
direct origin access cannot bypass that ingress. For a private proxy using
`x-sai-client-ip`, strip client copies, populate it from the verified peer address,
and block origin bypass. For managed Cloudflare ingress, confirm the actual
Supabase trust contract before enabling `cf-connecting-ip`. An echo probe on one
route alone cannot establish every route's behavior. Local mocked tests establish
parser/fallback behavior; they do not establish hosted ingress sanitization.

Missing configuration intentionally prevents public submissions/tracking/email
until ingress is verified. It does not block authorized status-update emails.
IP limits are an abuse control, not authorization or protection against distributed
clients. Applicant reference plus private token, staff authorization and RLS are
still required.

Cloudflare header semantics: https://developers.cloudflare.com/fundamentals/reference/http-headers/
Supabase caller-scoped client guidance: https://supabase.com/docs/guides/functions/auth-legacy-jwt

## Credential boundaries

Service-role keys remain server environment values and server-to-server client
headers. Tracking responses allowlist fields and public validation codes; raw
database messages are not returned. Notifications do not log provider response
bodies and omit untrusted prior audit status. Linking verifies the caller via
Auth, checks stored staff roles and branch membership, requires a verified target
account, and executes link/unlink RPCs with the caller JWT and anon key, not the
service-role credential. Linking errors are generic and responses are no-store.
Mocked regressions assert these boundaries using synthetic keys only.

Deployment remains a separate step: configure public function gateway JWT
behavior deliberately, verify required migrations and RPC grants, configure the
trusted IP source and email provider, and perform target-specific checks.
This local closeout does not validate hosted Auth, email delivery or gateway trust.
