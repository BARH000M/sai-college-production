import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("student linking verifies caller, branch and target and uses caller RPC credentials", async () => {
  const originalServe = Deno.serve;
  const originalFetch = globalThis.fetch;
  const env = {
    SUPABASE_URL: "https://local-test.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "local-service-secret",
    SUPABASE_ANON_KEY: "local-anon-key",
  };
  const oldEnv = Object.fromEntries(Object.keys(env).map((key) => [key, Deno.env.get(key)]));
  let handler: ((req: Request) => Promise<Response>) | undefined;
  let role = "admin";
  let verified = false;
  let branch = "branch-1";
  let upstreamError = false;
  let rpcError = false;
  const rpcCalls: { path: string; authorization: string | null; apikey: string | null; body: unknown }[] = [];
  try {
    for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
    Object.defineProperty(Deno, "serve", {
      configurable: true,
      value: (callback: (req: Request) => Promise<Response>) => { handler = callback; },
    });
    globalThis.fetch = async (input, init) => {
      const request = input instanceof Request ? input : new Request(input, init);
      const url = new URL(request.url);
      if (url.pathname === "/auth/v1/user") {
        assertEquals(request.headers.get("authorization"), "Bearer local-user-token");
        assertEquals(request.headers.get("apikey"), env.SUPABASE_ANON_KEY);
        return Response.json({ id: "caller-1", aud: "authenticated", role: "authenticated", app_metadata: {}, user_metadata: {} });
      }
      if (url.pathname === "/rest/v1/user_roles") {
        assertEquals(request.headers.get("apikey"), env.SUPABASE_SERVICE_ROLE_KEY);
        if (upstreamError) return Response.json({ message: env.SUPABASE_SERVICE_ROLE_KEY, code: "XX000" }, { status: 500 });
        return Response.json([{ role }]);
      }
      if (url.pathname === "/rest/v1/students") {
        return Response.json({ id: "20000000-0000-4000-8000-000000000001", branch_id: branch, user_id: null, full_name: "Student" });
      }
      if (url.pathname === "/rest/v1/branch_memberships") return Response.json([{ branch_id: "branch-1" }]);
      if (url.pathname === "/auth/v1/admin/users/10000000-0000-4000-8000-000000000001") {
        return Response.json({ user: { id: "10000000-0000-4000-8000-000000000001", email: "student@example.test", email_confirmed_at: verified ? "2026-01-01" : null } });
      }
      if (url.pathname.startsWith("/rest/v1/rpc/admissions_")) {
        rpcCalls.push({ path: url.pathname, authorization: request.headers.get("authorization"),
          apikey: request.headers.get("apikey"), body: await request.json() });
        if (rpcError) return Response.json({ message: env.SUPABASE_SERVICE_ROLE_KEY, code: "23505" }, { status: 409 });
        return Response.json(null);
      }
      throw new Error(`Unexpected mock request: ${url.pathname}`);
    };
    await import("./index.ts");
    if (!handler) throw new Error("Link handler missing");
    const request = (body: unknown, authenticated = true) => new Request("https://local-test.invalid", {
      method: "POST", headers: { "content-type": "application/json", ...(authenticated ? { authorization: "Bearer local-user-token" } : {}) },
      body: JSON.stringify(body),
    });
    const body = { action: "link", studentId: "20000000-0000-4000-8000-000000000001", userId: "10000000-0000-4000-8000-000000000001" };
    assertEquals((await handler(request(body, false))).status, 401);
    role = "teacher";
    assertEquals((await handler(request(body))).status, 403);
    role = "admin";
    assertEquals((await handler(request(null))).status, 400);
    assertEquals((await handler(request({ ...body, userId: "invalid" }))).status, 400);
    branch = "other-branch";
    assertEquals((await handler(request(body))).status, 403);
    branch = "branch-1";
    assertEquals((await handler(request(body))).status, 422);
    assertEquals(rpcCalls.length, 0);
    verified = true;
    const response = await handler(request(body));
    assertEquals(response.status, 200);
    assertEquals(response.headers.get("cache-control"), "no-store");
    assertEquals(await response.json(), { ok: true, email: "student@example.test" });
    assertEquals(rpcCalls[0], { path: "/rest/v1/rpc/admissions_link_student_account",
      authorization: "Bearer local-user-token", apikey: env.SUPABASE_ANON_KEY,
      body: { p_student_id: "20000000-0000-4000-8000-000000000001", p_user_id: "10000000-0000-4000-8000-000000000001" } });
    assertEquals((await handler(request({ action: "unlink", studentId: "20000000-0000-4000-8000-000000000001" }))).status, 200);
    assertEquals(rpcCalls[1].path, "/rest/v1/rpc/admissions_unlink_student_account");
    assertEquals(rpcCalls[1].authorization, "Bearer local-user-token");
    rpcError = true;
    const conflict = await handler(request(body));
    assertEquals(conflict.status, 409);
    assert(!(await conflict.text()).includes(env.SUPABASE_SERVICE_ROLE_KEY));
    upstreamError = true;
    const failed = await handler(request(body));
    assertEquals(failed.status, 500);
    assert(!(await failed.text()).includes(env.SUPABASE_SERVICE_ROLE_KEY));
  } finally {
    Object.defineProperty(Deno, "serve", { configurable: true, value: originalServe });
    globalThis.fetch = originalFetch;
    for (const [key, value] of Object.entries(oldEnv)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
});
