import { assertEquals, assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("role management enforces authorization, confirmations, branch scope, and atomic RPC errors", async () => {
  const serve = Deno.serve;
  const fetch = globalThis.fetch;
  const env = {
    SUPABASE_URL: "https://local-test.invalid",
    SUPABASE_ANON_KEY: "local-anon-key",
    SUPABASE_SERVICE_ROLE_KEY: "local-service-secret",
  };
  const previous = Object.fromEntries(Object.keys(env).map((key) => [key, Deno.env.get(key)]));
  let handler: ((req: Request) => Promise<Response>) | undefined;
  let superAdmin = true;
  let targetEmailConfirmed = true;
  let rpcError: string | null = null;
  let invalidAcknowledgement = false;
  let rpcCalls: Record<string, unknown>[] = [];
  let countCalls = 0;
  try {
    for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
    Object.defineProperty(Deno, "serve", { configurable: true, value: (callback: typeof handler) => { handler = callback; } });
    globalThis.fetch = async (input, init) => {
      const req = input instanceof Request ? input : new Request(input, init);
      const url = new URL(req.url);
      if (req.method === "HEAD") {
        countCalls += 1;
        return new Response(null, { headers: { "content-range": "0-2/3" } });
      }
      if (url.pathname === "/auth/v1/user") {
        return Response.json({ id: "caller", aud: "authenticated", email_confirmed_at: "2026-01-01", app_metadata: {}, user_metadata: {} });
      }
      if (url.pathname === "/rest/v1/user_roles" && url.searchParams.get("select") === "role") {
        return Response.json(superAdmin ? { role: "super_admin" } : null);
      }
      if (url.pathname.startsWith("/auth/v1/admin/users/")) {
        return Response.json({ user: {
          id: "00000000-0000-4000-8000-000000000001",
          email: "target@example.test",
          email_confirmed_at: targetEmailConfirmed ? "2026-01-01T00:00:00.000Z" : null,
          user_metadata: { full_name: "Target User" },
        } });
      }
      if (url.pathname === "/auth/v1/admin/users") {
        return Response.json({ users: [
          { id: "user-1", email: "one@example.test", email_confirmed_at: "2026-01-01" },
          { id: "user-2", email: "two@example.test", email_confirmed_at: null },
        ] });
      }
      if (url.pathname === "/rest/v1/rpc/sai_manage_role_assignment") {
        const body = await req.json();
        rpcCalls.push(body);
        if (rpcError) return Response.json({ code: rpcError, message: "mock database error" }, { status: 409 });
        return Response.json(invalidAcknowledgement ? null : { ok: true, action: body.p_action, role: body.p_role });
      }
      if (url.pathname === "/rest/v1/branches") return Response.json([]);
      if (url.pathname === "/rest/v1/branch_memberships") return Response.json([]);
      if (url.pathname === "/rest/v1/profiles") return Response.json([]);
      if (url.pathname === "/rest/v1/user_roles") return Response.json([{ user_id: "user-1" }]);
      throw new Error(`Unexpected mock request: ${url.pathname}`);
    };

    await import("./index.ts");
    if (!handler) throw new Error("Role handler missing");
    const request = (body: Record<string, unknown>) => new Request("https://local-test.invalid", {
      method: "POST",
      headers: { authorization: "Bearer local-user-token", "content-type": "application/json" },
      body: JSON.stringify(body),
    });

    const summaryResponse = await handler(request({ action: "summary" }));
    assertEquals(summaryResponse.status, 200);
    const { summary } = await summaryResponse.json();
    assertEquals(summary.totalUsers, 2);
    assertEquals(summary.usersWithoutRoles, 1);
    assertEquals(summary.pendingEmailConfirmation, 1);
    assertEquals(summary.emailConfirmedUsers, 1);
    assertEquals(summary.pendingAdmissions, 3);
    assertEquals(summary.totalRoleAssignments, 3);

    const previousCounts = countCalls;
    superAdmin = false;
    assertEquals((await handler(request({ action: "summary" }))).status, 403);
    assertEquals(countCalls, previousCounts);
    assertEquals((await handler(request({
      action: "grant",
      userId: "00000000-0000-4000-8000-000000000001",
      role: "student",
    }))).status, 403);
    assertEquals(rpcCalls.length, 0);

    superAdmin = true;
    const targetId = "00000000-0000-4000-8000-000000000001";
    const branchId = "00000000-0000-4000-8000-000000000002";
    const grant = (role: string, extra: Record<string, unknown> = {}) => handler!(request({
      action: "grant", userId: targetId, role, ...extra,
    }));

    assertEquals((await grant("teacher")).status, 422);
    assertEquals((await grant("super_admin")).status, 422);
    assertEquals(rpcCalls.length, 0);

    targetEmailConfirmed = false;
    const unverified = await grant("student");
    assertEquals(unverified.status, 422);
    assertMatch((await unverified.json()).code, /^email_verification_required$/);
    assertEquals(rpcCalls.length, 0);

    targetEmailConfirmed = true;
    assertEquals((await grant("teacher", { branchIds: [branchId] })).status, 200);
    assertEquals(rpcCalls.length, 1);
    assertEquals(rpcCalls[0].p_action, "grant");
    assertEquals(rpcCalls[0].p_role, "teacher");
    assertEquals(rpcCalls[0].p_branch_ids, [branchId]);
    assertEquals(rpcCalls[0].p_email_confirmed, true);

    assertEquals((await grant("super_admin", { confirmSuperAdminGrant: true })).status, 200);
    assertEquals(rpcCalls.at(-1)?.p_confirm_super_admin, true);

    rpcError = "23505";
    const duplicate = await handler(request({
      action: "grant", userId: targetId, role: "student",
    }));
    assertEquals(duplicate.status, 409);
    assertEquals((await duplicate.json()).code, "23505");
    rpcError = null;

    invalidAcknowledgement = true;
    const unconfirmed = await grant("student");
    assertEquals(unconfirmed.status, 500);
    assertEquals((await unconfirmed.json()).code, "role_operation_unconfirmed");
    invalidAcknowledgement = false;

    assertEquals((await handler(request({ action: "revoke", userId: targetId, role: "student" }))).status, 200);
    assertEquals(rpcCalls.at(-1)?.p_action, "revoke");
    assertEquals(rpcCalls.at(-1)?.p_branch_ids, []);

    rpcError = "23514";
    const lastAdmin = await handler(request({
      action: "revoke", userId: targetId, role: "super_admin",
    }));
    assertEquals(lastAdmin.status, 409);
    assertEquals((await lastAdmin.json()).code, "23514");
    rpcError = null;
  } finally {
    Object.defineProperty(Deno, "serve", { configurable: true, value: serve });
    globalThis.fetch = fetch;
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key); else Deno.env.set(key, value);
    }
  }
});
