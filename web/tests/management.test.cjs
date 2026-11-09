const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../src/lib/management.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__managementTestSupabase;");
const code = stripTypeScriptTypes(source, { mode: "strip" });
const modulePromise = import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}`);
const formCode = stripTypeScriptTypes(fs.readFileSync(path.join(__dirname, "../src/lib/managementForms.ts"), "utf8"), { mode: "strip" });
const formsPromise = import(`data:text/javascript;base64,${Buffer.from(formCode).toString("base64")}`);
const baseFilters = { search: "", branch: "", session: "", classId: "", status: "", page: 0 };

test("edit payloads omit identity, ownership and branch/session fields", async () => {
  const { makeDraft, managementPayload } = await formsPromise;
  for (const kind of ["classes", "students"]) {
    const draft = makeDraft(kind, { id: "row", branch_id: "b", session_id: "s", user_id: "u", teacher_id: "t" }, baseFilters);
    const values = managementPayload(kind, draft, true);
    for (const key of ["id", "branch_id", "session_id", "user_id", "teacher_id"]) assert.equal(key in values, false);
  }
});

test("form validation rejects invalid session dates and class capacity", async () => {
  const { makeDraft, validateManagementDraft } = await formsPromise;
  const session = makeDraft("sessions", null, baseFilters);
  Object.assign(session, { name: "Session", starts_on: "2026-04-01", ends_on: "2026-04-01" });
  assert.ok(validateManagementDraft("sessions", session, false));
  const classroom = makeDraft("classes", null, { ...baseFilters, branch: "b", session: "s" });
  Object.assign(classroom, { name: "Class", program: "Program", capacity: "0" });
  assert.ok(validateManagementDraft("classes", classroom, false));
  classroom.capacity = "20";
  assert.equal(validateManagementDraft("classes", classroom, false), null);
});

test("student class assignment cannot be saved from stale or failed options", async () => {
  const { isAvailableStudentClass } = await formsPromise;
  const classes = [{ id: "c1", name: "Class" }];
  assert.equal(isAvailableStudentClass("", [], false, null), true);
  assert.equal(isAvailableStudentClass("c1", classes, false, null), true);
  assert.equal(isAvailableStudentClass("c1", classes, true, null), false);
  assert.equal(isAvailableStudentClass("c1", classes, false, "error"), false);
  assert.equal(isAvailableStudentClass("missing", classes, false, null), false);
});

test("management controls follow the approved role exceptions", async () => {
  const { managementAccess } = await modulePromise;
  for (const kind of ["branches", "sessions", "classes", "students"]) {
    assert.deepEqual(managementAccess(kind, ["super_admin"]), { canCreate: true, canEdit: true });
    for (const role of ["teacher", "student", "parent", "receptionist", "librarian", "accountant", "content_editor"]) {
      assert.deepEqual(managementAccess(kind, [role]), { canCreate: false, canEdit: false });
    }
  }
  assert.deepEqual(managementAccess("branches", ["admin"]), { canCreate: false, canEdit: true });
  assert.deepEqual(managementAccess("sessions", ["admin"]), { canCreate: false, canEdit: false });
  assert.deepEqual(managementAccess("students", ["student", "admin"]), { canCreate: true, canEdit: true });
});

test("management source exposes deactivation without deletion operations", () => {
  for (const file of ["../src/pages/ManagementPage.tsx", "../src/lib/management.ts"]) {
    const text = fs.readFileSync(path.join(__dirname, file), "utf8");
    assert.doesNotMatch(text, /\.delete\s*\(|\btruncate\b|\bdelete\s+from\b/i);
  }
  const page = fs.readFileSync(path.join(__dirname, "../src/pages/ManagementPage.tsx"), "utf8");
  assert.match(page, /status: "inactive"/);
  assert.match(page, /is_active: false/);
});

function fakeSupabase(response = { data: [], count: 0, error: null }) {
  const calls = [];
  const builder = {
    select(...args) { calls.push(["select", ...args]); return this; },
    eq(...args) { calls.push(["eq", ...args]); return this; },
    is(...args) { calls.push(["is", ...args]); return this; },
    ilike(...args) { calls.push(["ilike", ...args]); return this; },
    order(...args) { calls.push(["order", ...args]); return this; },
    range(...args) { calls.push(["range", ...args]); return this; },
    returns() { return Promise.resolve(response); },
    update(...args) { calls.push(["update", ...args]); return this; },
    insert(...args) { calls.push(["insert", ...args]); return Promise.resolve(response); },
    then(resolve, reject) { return Promise.resolve(response).then(resolve, reject); },
  };
  return { calls, from(table) { calls.push(["from", table]); return builder; } };
}

test("student and class queries require branch and session scope", async () => {
  const api = await modulePromise;
  for (const kind of ["students", "classes"]) {
    const client = fakeSupabase();
    globalThis.__managementTestSupabase = client;
    // The test module binds the client at evaluation time.
    const isolated = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#${kind}`);
    assert.deepEqual(await isolated.loadManagementRows(kind, baseFilters), { rows: [], count: 0 });
    assert.deepEqual(client.calls, []);
  }
  assert.equal(api.pageSize, 25);
});

test("admin scope uses only the authenticated user's active memberships", async () => {
  const client = fakeSupabase({ data: [{ branch_id: "b1" }], count: 1, error: null });
  globalThis.__managementTestSupabase = client;
  const api = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#memberships`);
  assert.deepEqual(await api.loadManagementBranches("current-user"), ["b1"]);
  for (const [column, value] of [["user_id", "current-user"], ["is_active", true]]) {
    assert.ok(client.calls.some((call) => call[0] === "eq" && call[1] === column && call[2] === value));
  }
});

test("student session filters apply both branch and class session on the server", async () => {
  const client = fakeSupabase();
  globalThis.__managementTestSupabase = client;
  const api = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#scoped`);
  await api.loadManagementRows("students", { ...baseFilters, branch: "b1", session: "s1", classId: "c1", status: "active", page: 1 });
  assert.ok(client.calls.some((call) => call[0] === "select" && call[1].includes("classes!inner")));
  for (const [column, value] of [["branch_id", "b1"], ["classes.branch_id", "b1"], ["classes.session_id", "s1"], ["class_id", "c1"], ["status", "active"]]) {
    assert.ok(client.calls.some((call) => call[0] === "eq" && call[1] === column && call[2] === value));
  }
  assert.ok(client.calls.some((call) => call[0] === "range" && call[1] === 25 && call[2] === 49));
});

test("unassigned student filter is scoped to the selected branch", async () => {
  const client = fakeSupabase();
  globalThis.__managementTestSupabase = client;
  const api = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#unassigned`);
  await api.loadManagementRows("students", { ...baseFilters, branch: "b1", session: "unassigned" });
  assert.ok(client.calls.some((call) => call[0] === "eq" && call[1] === "branch_id" && call[2] === "b1"));
  assert.ok(client.calls.some((call) => call[0] === "is" && call[1] === "class_id" && call[2] === null));
});

test("filter options paginate instead of silently omitting rows", async () => {
  const starts = [];
  globalThis.__managementTestSupabase = {
    from(table) {
      let start = 0;
      const builder = {
        select() { return this; }, order() { return this; }, eq() { return this; },
        range(value) { start = value; if (table === "branches") starts.push(value); return this; },
        returns() {
          if (table !== "branches") return Promise.resolve({ data: [], count: 0, error: null });
          return Promise.resolve({ data: start === 0 ? [{ id: "1", name: "A" }, { id: "2", name: "B" }] : [{ id: "3", name: "C" }], count: 3, error: null });
        },
      };
      return builder;
    },
  };
  const api = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#pagination`);
  const result = await api.loadManagementOptions("", "");
  assert.equal(result.branches.length, 3);
  assert.deepEqual(starts, [0, 2]);
});

test("query errors and updates hidden by RLS are not reported as success", async () => {
  const client = fakeSupabase({ data: null, count: null, error: { message: "permission denied" } });
  globalThis.__managementTestSupabase = client;
  const api = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#errors`);
  await assert.rejects(api.loadManagementRows("branches", baseFilters), /permission denied/);
  await assert.rejects(api.saveManagementRow("branches", null, { name: "test" }), /permission denied/);
  client.from = () => ({ update: () => ({ eq: () => ({ select: async () => ({ data: [], error: null }) }) }) });
  await assert.rejects(api.saveManagementRow("branches", "hidden", { name: "test" }), /لم يُحدّث/);
});
