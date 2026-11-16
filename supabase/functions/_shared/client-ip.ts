import { isIP } from "node:net";

/** Only enable a header after ingress is verified to overwrite it on every route.
 * No X-Forwarded-For fallback: a caller can prepend arbitrary addresses.
 * Missing trust configuration or malformed/duplicated addresses fail closed.
 */
export function trustedClientIp(headers: Headers): string | null {
  const header = Deno.env.get("ADMISSIONS_TRUSTED_IP_HEADER");
  if (header !== "cf-connecting-ip" && header !== "x-sai-client-ip") return null;
  const ip = headers.get(header)?.trim();
  if (!ip || ip.includes("%") || !isIP(ip)) return null;
  // Normalize equivalent IPv6 spellings so they share one rate-limit bucket.
  return isIP(ip) === 6 ? new URL(`http://[${ip}]/`).hostname.slice(1, -1) : ip;
}
