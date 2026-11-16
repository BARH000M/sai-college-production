const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const root = path.resolve(__dirname, "../..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const dataUrl = (source) => `data:text/javascript;base64,${Buffer.from(
  stripTypeScriptTypes(source, { mode: "strip" }),
).toString("base64")}`;

async function loadRoles(client = {}) {
  globalThis.__rolesTestClient = client;
  const source = read("src/portal/lib/roles.ts")
    .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__rolesTestClient;")
    .replace('import { functionFailure } from "./functionErrors";', "const functionFailure = async () => new Error('test');");
  return import(`${dataUrl(source)}#${Math.random()}`);
}

test("directory rejects an incomplete response instead of reporting an empty account list", async () => {
  const { loadDirectoryUsers } = await loadRoles({
    functions: { invoke: async () => ({ data: { ok: true, branches: [] }, error: null }) },
  });
  await assert.rejects(loadDirectoryUsers(), /لا تتضمن قائمة الحسابات ونطاق الفروع/);
});

async function loadOnboarding() {
  return import(`${dataUrl(read("src/portal/lib/onboarding.ts"))}#${Math.random()}`);
}

test("the role assignment contract keeps all nine roles and scopes only staff roles", async () => {
  const { assignableRoles, isBranchScopedRole } = await loadRoles();
  const navigation = await import(`${dataUrl(read("src/portal/lib/navigation.ts"))}#${Math.random()}`);
  assert.deepEqual(
    assignableRoles.map((role) => role.id).sort(),
    Object.keys(navigation.roleLabels).sort(),
  );
  assert.deepEqual(
    assignableRoles.filter((role) => isBranchScopedRole(role.id)).map((role) => role.id).sort(),
    ["accountant", "admin", "content_editor", "librarian", "receptionist", "teacher"],
  );
  assert.equal(isBranchScopedRole("super_admin"), false);
  assert.equal(isBranchScopedRole("student"), false);
  assert.equal(isBranchScopedRole("parent"), false);
});

test("onboarding notices distinguish visible missing links from unavailable checks without blocking role unions", async () => {
  const { onboardingNotices } = await loadOnboarding();
  const incomplete = onboardingNotices(
    ["teacher", "student", "parent", "accountant"],
    true,
    {
      activeBranchMembership: false,
      studentRecordVisible: false,
      verifiedParentLinkVisible: false,
      assignedClassVisible: false,
    },
    null,
  );
  assert.equal(incomplete.length, 4);
  assert.ok(incomplete.some((message) => message.includes("عضوية فرع")));
  assert.ok(incomplete.some((message) => message.includes("سجل طالب")));
  assert.ok(incomplete.some((message) => message.includes("علاقة طالب موثقة")));
  assert.ok(incomplete.some((message) => message.includes("صف نشط")));

  assert.deepEqual(onboardingNotices(["super_admin"], true, {
    activeBranchMembership: false,
    studentRecordVisible: null,
    verifiedParentLinkVisible: null,
    assignedClassVisible: null,
  }, null), []);

  const unavailable = onboardingNotices(["parent"], true, {
    activeBranchMembership: null,
    studentRecordVisible: null,
    verifiedParentLinkVisible: null,
    assignedClassVisible: null,
  }, "RLS read failed");
  assert.equal(unavailable.length, 1);
  assert.match(unavailable[0], /تعذر التحقق/);
});

test("atomic role proposal validates scope and protects the last super administrator", () => {
  const migration = read("supabase/migrations/20261116142308_atomic_role_management.sql");
  assert.match(migration, /pg_advisory_xact_lock/);
  assert.match(migration, /last_usable_super_admin_protected/);
  assert.match(migration, /inactive_or_unknown_branch/);
  assert.match(migration, /branch_required/);
  assert.match(migration, /insert into public\.audit_logs/);
  assert.match(migration, /revoke all on function[\s\S]*from public, anon, authenticated/);
  assert.match(migration, /to service_role/);
  assert.doesNotMatch(migration, /\bgrant\s+all\b|\bto\s+public\b/i);
  // The main RPC must remain SECURITY INVOKER; the narrow auth-usability
  // helper's definer restrictions are asserted in branch-membership-lockdown.test.cjs.
  assert.match(migration, /function public\.sai_manage_role_assignment[\s\S]*?security invoker\s*set search_path = ''/);
});
