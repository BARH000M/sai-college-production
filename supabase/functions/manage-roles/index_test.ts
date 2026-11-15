import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("dashboard summary keeps role counts and refuses non-super administrators", async () => {
  const serve = Deno.serve;
  const fetch = globalThis.fetch;
  const env = { SUPABASE_URL: "https://local-test.invalid", SUPABASE_ANON_KEY: "local-anon-key", SUPABASE_SERVICE_ROLE_KEY: "local-service-secret" };
  const previous = Object.fromEntries(Object.keys(env).map((key) => [key, Deno.env.get(key)]));
  let handler: ((req: Request) => Promise<Response>) | undefined;
  let superAdmin = true;
  let countCalls = 0;
  try {
    for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
    Object.defineProperty(Deno, "serve", { configurable: true, value: (callback: typeof handler) => { handler = callback; } });
    globalThis.fetch = async (input, init) => {
      const req = input instanceof Request ? input : new Request(input, init);
      const url = new URL(req.url);
      if (url.pathname === "/auth/v1/user") return Response.json({ id: "caller", aud: "authenticated", app_metadata: {}, user_metadata: {} });
      if (url.pathname === "/rest/v1/user_roles" && url.searchParams.get("select") === "role") return Response.json(superAdmin ? { role: "super_admin" } : null);
      if (url.pathname === "/auth/v1/admin/users") return Response.json({ users: [
        { id: "user-1", email: "one@example.test", email_confirmed_at: "2026-01-01" },
        { id: "user-2", email: "two@example.test", email_confirmed_at: null },
      ] });
      if (req.method === "HEAD") {
        countCalls += 1;
        return new Response(null, { headers: { "content-range": "0-2/3" } });
      }
      if (url.pathname === "/rest/v1/user_roles") return Response.json([{ user_id: "user-1" }]);
      throw new Error(`Unexpected mock request: ${url.pathname}`);
    };
    await import("./index.ts");
    if (!handler) throw new Error("Role handler missing");
    const request = () => new Request("https://local-test.invalid", {
      method: "POST", headers: { authorization: "Bearer local-user-token", "content-type": "application/json" },
      body: JSON.stringify({ action: "summary" }),
    });
    const response = await handler(request());
    assertEquals(response.status, 200);
    const { summary } = await response.json();
    assertEquals(summary.totalUsers, 2);
    assertEquals(summary.usersWithoutRoles, 1);
    assertEquals(summary.pendingEmailConfirmation, 1);
    assertEquals(summary.emailConfirmedUsers, 1);
    assertEquals(summary.pendingAdmissions, 3);
    assertEquals(summary.totalRoleAssignments, 3);
    const previousCounts = countCalls;
    superAdmin = false;
    assertEquals((await handler(request())).status, 403);
    assertEquals(countCalls, previousCounts);
  } finally {
    Object.defineProperty(Deno, "serve", { configurable: true, value: serve });
    globalThis.fetch = fetch;
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key); else Deno.env.set(key, value);
    }
  }
});
