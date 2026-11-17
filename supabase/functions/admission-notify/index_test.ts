import { assert, assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("status email excludes untrusted previous status and server credentials", async () => {
  const originalServe = Deno.serve;
  const originalFetch = globalThis.fetch;
  const env = {
    ADMISSIONS_TRUSTED_IP_HEADER: "cf-connecting-ip",
    SUPABASE_URL: "https://local-test.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "local-service-secret",
    SUPABASE_ANON_KEY: "local-anon-key",
    RESEND_API_KEY: "local-resend-secret",
    RESEND_FROM_DOMAIN: "example.test",
  };
  const oldEnv = Object.fromEntries(Object.keys(env).map((key) => [key, Deno.env.get(key)]));
  let handler: ((request: Request) => Promise<Response>) | undefined;
  let emailHtml = "";
  let emailCalls = 0;
  let maintenance = false;
  try {
    for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
    Object.defineProperty(Deno, "serve", {
      configurable: true,
      value: (callback: (request: Request) => Promise<Response>) => { handler = callback; },
    });
    globalThis.fetch = async (input, init) => {
      const url = input instanceof Request ? input.url : String(input);
      if (url.endsWith("/rpc/sai_assert_mutations_enabled")) {
        return maintenance
          ? Response.json({ code: "55000", message: "maintenance_mode" }, { status: 400 })
          : Response.json(null);
      }
      if (url.endsWith("/rpc/sai_admission_status_email_context")) {
        return Response.json([{
          application_no: "ADM-1234", applicant_full_name: "Applicant", email: "applicant@example.test",
          status: "accepted", previous_status: "rejected", preferred_program: null,
          preferred_level: null, branch_name: null, session_name: null, occurrence: "2026-01-01",
        }]);
      }
      if (url === "https://api.resend.com/emails") {
        const body = JSON.parse(String(init?.body)) as { html: string };
        emailHtml = body.html;
        emailCalls += 1;
        return Response.json({ id: "local-email" });
      }
      throw new Error(`Unexpected mock request: ${url}`);
    };
    await import("./index.ts");
    if (!handler) throw new Error("Admission notification handler was not registered");
    const response = await handler(new Request("https://local-test.invalid", {
      method: "POST",
      headers: { "content-type": "application/json", authorization: "Bearer local-user-token" },
      body: JSON.stringify({ mode: "status_update", enquiryId: "12345678-1234-1234-1234-123456789abc" }),
    }));
    assertEquals(response.status, 200);
    const body = await response.text();
    assertEquals(JSON.parse(body), { ok: true, sent: true });
    assertStringIncludes(emailHtml, "تم القبول");
    assertStringIncludes(emailHtml, "آخر تحديث للطلب");
    assert(!emailHtml.includes("الحالة السابقة"));
    assert(!emailHtml.includes("الطلب غير مقبول"));
    const untrusted = await handler(new Request("https://local-test.invalid", {
      method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "192.0.2.99" },
      body: JSON.stringify({ mode: "submitted", reference: "ADM-1234", trackingToken: "a".repeat(64) }),
    }));
    assertEquals(untrusted.status, 503);
    assertEquals(await untrusted.json(), { ok: false, reason: "SERVICE_UNAVAILABLE" });
    assert(!body.includes(env.SUPABASE_SERVICE_ROLE_KEY));
    assert(!emailHtml.includes(env.SUPABASE_SERVICE_ROLE_KEY));
    maintenance = true;
    const held = await handler(new Request("https://local-test.invalid", {
      method: "POST",
      headers: { "content-type": "application/json", authorization: "Bearer local-user-token" },
      body: JSON.stringify({ mode: "status_update", enquiryId: "12345678-1234-1234-1234-123456789abc" }),
    }));
    assertEquals(held.status, 503);
    assertEquals(emailCalls, 1);
  } finally {
    Object.defineProperty(Deno, "serve", { configurable: true, value: originalServe });
    globalThis.fetch = originalFetch;
    for (const [key, value] of Object.entries(oldEnv)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
});
