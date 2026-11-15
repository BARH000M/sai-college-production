import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { trustedClientIp } from "./client-ip.ts";

Deno.test("client IP requires configured ingress and rejects spoofable fallback", () => {
  const previous = Deno.env.get("ADMISSIONS_TRUSTED_IP_HEADER");
  try {
    Deno.env.delete("ADMISSIONS_TRUSTED_IP_HEADER");
    assertEquals(trustedClientIp(new Headers({ "cf-connecting-ip": "192.0.2.1" })), null);
    Deno.env.set("ADMISSIONS_TRUSTED_IP_HEADER", "x-forwarded-for");
    assertEquals(trustedClientIp(new Headers({ "x-forwarded-for": "192.0.2.1" })), null);
    Deno.env.set("ADMISSIONS_TRUSTED_IP_HEADER", "cf-connecting-ip");
    assertEquals(trustedClientIp(new Headers({ "x-forwarded-for": "192.0.2.1" })), null);
    assertEquals(trustedClientIp(new Headers({
      "cf-connecting-ip": "192.0.2.1", "x-forwarded-for": "203.0.113.99, 198.51.100.2",
    })), "192.0.2.1");
    for (const value of ["", "unknown", "192.0.2.1, 192.0.2.2", "192.0.2.1:80", "999.0.0.1", "fe80::1%eth0"]) {
      assertEquals(trustedClientIp(new Headers({ "cf-connecting-ip": value })), null);
    }
    assertEquals(trustedClientIp(new Headers({ "cf-connecting-ip": "2001:0DB8:0:0:0:0:0:1" })), "2001:db8::1");
    Deno.env.set("ADMISSIONS_TRUSTED_IP_HEADER", "x-sai-client-ip");
    assertEquals(trustedClientIp(new Headers({ "x-sai-client-ip": "192.0.2.2" })), "192.0.2.2");
  } finally {
    if (previous === undefined) Deno.env.delete("ADMISSIONS_TRUSTED_IP_HEADER");
    else Deno.env.set("ADMISSIONS_TRUSTED_IP_HEADER", previous);
  }
});
