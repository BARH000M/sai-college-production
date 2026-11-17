import { assertEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("invitations never grant access, auto-confirm email, link records or delete accounts", async () => {
  const serve = Deno.serve; const fetch = globalThis.fetch;
  const env = { SUPABASE_URL: "https://local-test.invalid", SUPABASE_ANON_KEY: "local-anon", SUPABASE_SERVICE_ROLE_KEY: "local-secret", PHASE3B_MUTATIONS_DISABLED: "false" };
  const old = Object.fromEntries(Object.keys(env).map((k) => [k, Deno.env.get(k)]));
  let handler: ((request: Request) => Promise<Response>) | undefined;
  let auditFails = false;
  let roleAllowed = true;
  let invites = 0;
  try {
    for (const [k, v] of Object.entries(env)) Deno.env.set(k, v);
    Object.defineProperty(Deno, "serve", { configurable: true, value: (fn: typeof handler) => handler = fn });
    globalThis.fetch = async (input, init) => {
      const req = input instanceof Request ? input : new Request(input, init);
      const url = new URL(req.url);
      assert(req.method !== "DELETE", "Provisioning must never delete an account");
      if (url.pathname === "/auth/v1/user") return Response.json({ id: "actor", email_confirmed_at: "2026-01-01" });
      if (url.pathname === "/rest/v1/user_roles") {
        assertEquals(req.method, "GET"); return Response.json(roleAllowed ? { role: "super_admin" } : null);
      }
      if (url.pathname === "/rest/v1/students") {
        assertEquals(req.method, "GET"); return Response.json({ id: "student", full_name: "Student", user_id: null });
      }
      if (url.pathname === "/rest/v1/classes") {
        assertEquals(req.method, "GET"); return Response.json({ id: "class", branch_id: "branch", name: "Class", teacher_id: null });
      }
      if (url.pathname === "/rest/v1/parent_student_links") { assertEquals(req.method, "GET"); return Response.json(null); }
      if (url.pathname === "/auth/v1/invite") {
        const body = await req.json();
        assertEquals("password" in body, false); assertEquals("email_confirm" in body, false);
        invites++; return Response.json({ id: "new-account", email: body.email, email_confirmed_at: null });
      }
      if (url.pathname === "/rest/v1/profiles") return Response.json(null);
      if (url.pathname === "/rest/v1/audit_logs") return auditFails
        ? Response.json({ code: "42501", message: "test audit denied" }, { status: 403 }) : Response.json(null);
      throw new Error(`Unexpected privileged mutation: ${req.method} ${url.pathname}`);
    };
    await import("./index.ts"); assert(handler);
    const request = (body: Record<string, unknown>) => new Request("https://local-test.invalid", {
      method: "POST", headers: { authorization: "Bearer actor-token", "content-type": "application/json" }, body: JSON.stringify(body),
    });
    for (const kind of ["student", "parent"]) {
      const response = await handler(request({ action: "create", studentId: "student", kind, email: `${kind}@example.test` }));
      assertEquals(response.status, 200);
      const result = await response.json();
      assertEquals(result.account.inviteSent, true); assertEquals(result.account.roleActivationPending, true);
      assertEquals("password" in result.account, false);
    }
    const teacher = await handler(request({ action: "create-teacher", classId: "class", fullName: "Teacher", email: "teacher@example.test" }));
    assertEquals(teacher.status, 200); assertEquals((await teacher.json()).account.roleActivationPending, true);
    assertEquals(invites, 3);
    roleAllowed = false;
    assertEquals((await handler(request({ action: "create", studentId: "student", kind: "student", email: "denied@example.test" }))).status, 403);
    assertEquals(invites, 3);
    roleAllowed = true; auditFails = true;
    const incomplete = await handler(request({ action: "create", studentId: "student", kind: "student", email: "pending@example.test" }));
    assertEquals(incomplete.status, 500); assertEquals((await incomplete.json()).code, "invite_setup_incomplete");
    const before = invites;
    Deno.env.set("PHASE3B_MUTATIONS_DISABLED", "true");
    assertEquals((await handler(request({ action: "create-teacher", classId: "class", fullName: "Teacher", email: "hold@example.test" }))).status, 503);
    assertEquals(invites, before);
  } finally {
    Object.defineProperty(Deno, "serve", { configurable: true, value: serve }); globalThis.fetch = fetch;
    for (const [k, v] of Object.entries(old)) { if (v === undefined) Deno.env.delete(k); else Deno.env.set(k, v); }
  }
});
