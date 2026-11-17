import { assertEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("legacy role routes use the modern confirmed, scoped and atomic contract", async () => {
  const originalServe = Deno.serve;
  const originalFetch = globalThis.fetch;
  const keys = { SUPABASE_URL: "https://local-test.invalid", SUPABASE_ANON_KEY: "local-anon", SUPABASE_SERVICE_ROLE_KEY: "local-secret", PHASE3B_MUTATIONS_DISABLED: "false" };
  const old = Object.fromEntries(Object.keys(keys).map((k) => [k, Deno.env.get(k)]));
  let handler: ((request: Request) => Promise<Response>) | undefined;
  let allowed = true;
  let rpcError: string | null = null;
  const calls: Record<string, unknown>[] = [];
  try {
    for (const [k, v] of Object.entries(keys)) Deno.env.set(k, v);
    Object.defineProperty(Deno, "serve", { configurable: true, value: (fn: typeof handler) => handler = fn });
    globalThis.fetch = async (input, init) => {
      const req = input instanceof Request ? input : new Request(input, init);
      const u = new URL(req.url);
      if (u.pathname === "/auth/v1/user") return Response.json({ id: "actor", email_confirmed_at: "2026-01-01" });
      if (u.pathname === "/auth/v1/admin/users") return Response.json({ users: [] });
      if (u.pathname.startsWith("/auth/v1/admin/users/")) return Response.json({ user: { id: "00000000-0000-4000-8000-000000000002", email: "target@example.test", email_confirmed_at: "2026-01-01" } });
      if (u.pathname === "/rest/v1/user_roles") {
        assertEquals(req.method, "GET", "Legacy direct role mutation survived");
        const single = (req.headers.get("accept") ?? "").includes("object");
        return Response.json(u.searchParams.get("select") === "role"
          ? (single ? (allowed ? { role: "super_admin" } : null) : (allowed ? [{ role: "super_admin" }] : [])) : []);
      }
      if (u.pathname === "/rest/v1/rpc/sai_assert_mutations_enabled") return Response.json(null);
      if (u.pathname === "/rest/v1/profiles") return Response.json([]);
      if (u.pathname === "/rest/v1/rpc/sai_manage_role_assignment") {
        const body = await req.json(); calls.push(body);
        if (rpcError) return Response.json({ code: rpcError, message: "private failure" }, { status: 409 });
        return Response.json({ ok: true, action: body.p_action, role: body.p_role });
      }
      throw new Error(`Unexpected request ${req.method} ${u.pathname}`);
    };
    await import("./index.ts");
    assert(handler);
    const request = (action: string, payload: Record<string, unknown> = {}) => new Request("https://local-test.invalid", {
      method: "POST", headers: { authorization: "Bearer actor-token", "content-type": "application/json" },
      body: JSON.stringify({ action, payload }),
    });
    const target = { userId: "00000000-0000-4000-8000-000000000002" };
    assertEquals((await handler(request("grant-role", { ...target, role: "teacher" }))).status, 422);
    assertEquals((await handler(request("grant-role", { ...target, role: "super_admin" }))).status, 422);
    assertEquals(calls.length, 0);
    allowed = false;
    assertEquals((await handler(request("grant-role", { ...target, role: "student" }))).status, 403);
    allowed = true;
    const result = await handler(request("grant-role", { ...target, role: "teacher", branchIds: ["20000000-0000-4000-8000-000000000001"], p_actor_id: "forged" }));
    assertEquals(result.status, 200);
    assertEquals((await result.json()).data.changed, true);
    assertEquals(calls[0].p_actor_id, "actor");
    rpcError = "23514";
    const last = await handler(request("revoke-role", { ...target, role: "super_admin" }));
    assertEquals(last.status, 409);
    assert(!(await last.text()).includes("private failure"));
    assertEquals((await handler(request("directory"))).status, 200);
    assertEquals((await handler(request("submit-application", { fullName: "x" }))).status, 400);
    const before = calls.length;
    Deno.env.set("PHASE3B_MUTATIONS_DISABLED", "true");
    assertEquals((await handler(request("revoke-role", { ...target, role: "super_admin" }))).status, 503);
    assertEquals(calls.length, before);
  } finally {
    Object.defineProperty(Deno, "serve", { configurable: true, value: originalServe });
    globalThis.fetch = originalFetch;
    for (const [k, v] of Object.entries(old)) { if (v === undefined) Deno.env.delete(k); else Deno.env.set(k, v); }
  }
});
