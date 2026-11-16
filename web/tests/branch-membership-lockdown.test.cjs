const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const lockdown = read("supabase/migrations/20261116151509_branch_membership_write_lockdown.sql");
const atomic = read("supabase/migrations/20261116142308_atomic_role_management.sql");
const noComments = (sql) => sql.replace(/--[^\n]*/g, "");

test("branch lockdown revokes authenticated writes at both table and column level", () => {
  const sql = noComments(lockdown);
  assert.match(sql, /revoke insert, update, delete on public\.branch_memberships from authenticated/i);
  assert.match(sql, /revoke insert \(user_id, branch_id, is_active\), update \(user_id, branch_id, is_active\)\s*on public\.branch_memberships from authenticated/i);
  assert.doesNotMatch(sql, /revoke[^;]*\bselect\b[^;]*branch_memberships/i);
  assert.doesNotMatch(sql, /\bdisable row level|\bgrant\s+all|\bto\s+public\b|\bsecurity\s+definer\b/i);
  assert.doesNotMatch(sql, /\b(?:insert|update|delete)\s+(?:into\s+)?public\.branch_memberships\b/i);
});

test("branch lockdown replaces self-update with a super-admin-only update policy", () => {
  const sql = noComments(lockdown);
  assert.match(sql, /drop policy if exists branch_memberships_update_self_or_super_admin/i);
  assert.doesNotMatch(sql, /drop policy[^;]*branch_memberships_select_self_or_super_admin/i);
  assert.doesNotMatch(sql, /drop policy[^;]*branch_memberships_insert_super_admin/i);
  assert.match(sql, /create policy branch_memberships_update_super_admin[\s\S]*?for update to authenticated[\s\S]*?using \(private\.sai_security_has_role\('super_admin'\)\)[\s\S]*?with check \(private\.sai_security_has_role\('super_admin'\)\)/i);
});

test("no browser code writes branch_memberships directly", () => {
  for (const dir of ["src", "mobile/lib"]) {
    const visit = (d) => fs.readdirSync(d, { withFileTypes: true })
      .flatMap((e) => (e.isDirectory() ? visit(path.join(d, e.name)) : [path.join(d, e.name)]));
    for (const file of visit(path.join(root, dir)).filter((f) => /\.(tsx?|dart)$/.test(f))) {
      const source = fs.readFileSync(file, "utf8");
      for (const match of source.matchAll(/\.from\(["']branch_memberships["']\)([^;]*)/gs)) {
        assert.doesNotMatch(match[1], /\.(insert|update|upsert|delete)\(/, path.relative(root, file));
      }
    }
  }
});

test("last-usable-super-admin protection verifies Auth usability, not just role rows", () => {
  const sql = noComments(atomic);
  assert.match(sql, /create or replace function private\.sai_has_other_usable_super_admin\(p_target_id uuid\)/);
  assert.match(sql, /join auth\.users as remaining_user/);
  assert.match(sql, /email_confirmed_at is not null/);
  assert.match(sql, /deleted_at is null/);
  assert.match(sql, /banned_until is null\s*or\s*remaining_user\.banned_until <= pg_catalog\.now\(\)/);
  assert.match(sql, /last_usable_super_admin_protected/);
  assert.doesNotMatch(sql, /last_super_admin_protected/);
  // Row-count-only protection must be gone.
  assert.doesNotMatch(sql, /count\(\*\)[\s\S]{0,200}<=\s*1/);
  // The check must run under the same transaction advisory lock as the mutation.
  assert.ok(sql.indexOf("pg_advisory_xact_lock") < sql.indexOf("sai_has_other_usable_super_admin(p_target_id)"));
});

test("the usability helper is a narrow definer function executable only by service_role", () => {
  const sql = noComments(atomic);
  const helper = sql.slice(sql.indexOf("private.sai_has_other_usable_super_admin(p_target_id uuid)"));
  assert.match(helper, /security definer\s*set search_path = pg_catalog, public, auth/);
  assert.match(sql, /revoke all on function private\.sai_has_other_usable_super_admin\(uuid\)\s*from public, anon, authenticated/);
  assert.match(sql, /grant execute on function private\.sai_has_other_usable_super_admin\(uuid\)\s*to service_role/);
  // The helper returns only a boolean and selects no auth data into results.
  assert.doesNotMatch(helper.slice(0, helper.indexOf("$function$;")), /returns\s+(?!boolean)/i);
  // The main RPC remains SECURITY INVOKER with an empty search_path.
  assert.match(sql, /function public\.sai_manage_role_assignment[\s\S]*?security invoker\s*set search_path = ''/);
});

test("isolated SQL tests exist for both blockers and require operator-supplied markers", () => {
  for (const [file, marker] of [
    ["supabase/tests/role_management_atomic.sql", "sai.role_management_isolated_test"],
    ["supabase/tests/branch_membership_lockdown.sql", "sai.branch_lockdown_test"],
  ]) {
    const sql = read(file);
    assert.match(sql, new RegExp(`current_setting\\('${marker.replace(/\./g, "\\.")}', true\\)`));
    assert.doesNotMatch(sql, new RegExp(`select set_config\\('${marker.replace(/\./g, "\\.")}'`));
    assert.match(sql, /\brollback;/);
    assert.match(sql, /as result;\s*$/);
    assert.match(sql, /ISOLATED LOCAL DATABASE ONLY/);
  }
  const lockdownTest = read("supabase/tests/branch_membership_lockdown.sql");
  assert.match(lockdownTest, /set local role authenticated/);
  assert.match(lockdownTest, /when insufficient_privilege then/);
  assert.match(lockdownTest, /set local role service_role/);
  const atomicTest = read("supabase/tests/role_management_atomic.sql");
  assert.match(atomicTest, /banned_until = now\(\) \+ interval '1 day'/);
  assert.match(atomicTest, /deleted_at = now\(\)/);
  assert.match(atomicTest, /Unusable Super Admins were counted as revocation protection/);
});
