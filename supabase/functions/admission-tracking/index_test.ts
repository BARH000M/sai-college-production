import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("history preserves snapshots and rejects malformed events", async () => {
  const originalServe = Deno.serve;
  const originalFetch = globalThis.fetch;
  const oldUrl = Deno.env.get("SUPABASE_URL");
  const oldHeader = Deno.env.get("ADMISSIONS_TRUSTED_IP_HEADER");
  const oldKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  let handler: ((request: Request) => Promise<Response>) | undefined;
  let submitError = { code: "22023", message: "local-test-key" };
  let events: unknown = [{
    action: "current_status_snapshot",
    status: "accepted",
    occurred_at: "2026-01-01T00:00:00Z",
    applicant_full_name: "must not be returned",
  }];
  let status: unknown = {
    status: "accepted", submitted_at: "2026-01-01", status_updated_at: "2026-01-02",
    applicant_full_name: "must not be returned", email: "private@example.test",
  };
  try {
    Deno.env.set("ADMISSIONS_TRUSTED_IP_HEADER", "cf-connecting-ip");
    Deno.env.set("SUPABASE_URL", "https://local-test.invalid");
    Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "local-test-key");
    Object.defineProperty(Deno, "serve", {
      configurable: true,
      value: (callback: (request: Request) => Promise<Response>) => { handler = callback; },
    });
    globalThis.fetch = async (input) => {
      const url = input instanceof Request ? input.url : String(input);
      if (url.endsWith("/rpc/admissions_public_rate_limit")) {
        return Response.json(true);
      }
      if (url.endsWith("/rpc/admissions_public_submit")) {
        return Response.json(submitError, { status: 400 });
      }
      if (url.endsWith("/rpc/admissions_public_history")) {
        return Response.json(events);
      }
      if (url.endsWith("/rpc/admissions_public_status")) {
        return Response.json(status);
      }
      throw new Error(`Unexpected mock request: ${url}`);
    };
    await import("./index.ts");
    if (!handler) throw new Error("Admission tracking handler was not registered");
    const request = () => new Request("https://local-test.invalid", {
      method: "POST",
      headers: { "content-type": "application/json", "cf-connecting-ip": "192.0.2.1", "x-forwarded-for": "203.0.113.99" },
      body: JSON.stringify({ mode: "history", reference: "ADM-1234", trackingToken: "a".repeat(64) }),
    });
    const spoofed = request();
    spoofed.headers.delete("cf-connecting-ip");
    const unavailable = await handler(spoofed);
    assertEquals(unavailable.status, 503);
    assertEquals(await unavailable.json(), { ok: false, code: "SERVICE_UNAVAILABLE" });
    const response = await handler(request());
    assertEquals(response.status, 200);
    assertEquals(await response.json(), {
      ok: true,
      history: [{ action: "current_status_snapshot", status: "accepted", occurred_at: "2026-01-01T00:00:00Z" }],
    });
    const submission = () => new Request("https://local-test.invalid", {
      method: "POST", headers: { "content-type": "application/json", "cf-connecting-ip": "192.0.2.1" },
      body: JSON.stringify({ mode: "submit", fullName: "Applicant", phone: "777123456" }),
    });
    const failedSubmission = await handler(submission());
    assertEquals(failedSubmission.status, 400);
    assertEquals(await failedSubmission.json(), { ok: false, code: "INVALID_REQUEST" });
    submitError = { code: "22023", message: "INVALID_NAME" };
    assertEquals(await (await handler(submission())).json(), { ok: false, code: "INVALID_NAME" });
    events = [{ action: "untrusted", status: "accepted", occurred_at: "2026-01-01T00:00:00Z" }];
    const invalid = await handler(request());
    assertEquals(invalid.status, 500);
    assertEquals(await invalid.json(), { ok: false, code: "LOOKUP_FAILED" });

    const statusRequest = (reference: string, token: string) => new Request("https://local-test.invalid", {
      method: "POST",
      headers: { "content-type": "application/json", "cf-connecting-ip": "192.0.2.1", "x-forwarded-for": "203.0.113.99" },
      body: JSON.stringify({ mode: "status", reference, trackingToken: token }),
    });
    const visible = await handler(statusRequest("ADM-1234", "a".repeat(64)));
    assertEquals(await visible.json(), {
      ok: true, result: { status: "accepted", submitted_at: "2026-01-01", status_updated_at: "2026-01-02" },
    });
    status = null;
    const wrongToken = await handler(statusRequest("ADM-1234", "b".repeat(64)));
    const unknownReference = await handler(statusRequest("UNKNOWN", "b".repeat(64)));
    assertEquals(await wrongToken.json(), { ok: true, result: null });
    assertEquals(await unknownReference.json(), { ok: true, result: null });
  } finally {
    Object.defineProperty(Deno, "serve", { configurable: true, value: originalServe });
    globalThis.fetch = originalFetch;
    if (oldHeader === undefined) Deno.env.delete("ADMISSIONS_TRUSTED_IP_HEADER");
    else Deno.env.set("ADMISSIONS_TRUSTED_IP_HEADER", oldHeader);
    if (oldUrl === undefined) Deno.env.delete("SUPABASE_URL");
    else Deno.env.set("SUPABASE_URL", oldUrl);
    if (oldKey === undefined) Deno.env.delete("SUPABASE_SERVICE_ROLE_KEY");
    else Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", oldKey);
  }
});
