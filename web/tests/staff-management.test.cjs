const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../../src/portal/lib/unifiedModules.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__hrTestSupabase;");
const code = stripTypeScriptTypes(source, { mode: "strip" });

function client(response) {
  const calls = [];
  const builder = {
    select(...args) { calls.push(["select", ...args]); return this; },
    eq(...args) { calls.push(["eq", ...args]); return this; },
    order(...args) { calls.push(["order", ...args]); return this; },
    limit(...args) { calls.push(["limit", ...args]); return this; },
    insert(...args) { calls.push(["insert", ...args]); return this; },
    update(...args) { calls.push(["update", ...args]); return this; },
    delete(...args) { calls.push(["delete", ...args]); return this; },
    then(resolve, reject) { return Promise.resolve(response).then(resolve, reject); },
  };
  return {
    calls,
    from(table) { calls.push(["from", table]); return builder; },
  };
}

test("staff directory is branch-scoped and restricted to HR administrators", async () => {
  globalThis.__hrTestSupabase = client({ data: [], error: null });
  const api = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#staff-access`);
  const spec = api.unifiedModules.staff;
  assert.equal(spec.table, "sai_hr_employees");
  assert.deepEqual([...spec.roles], ["super_admin", "admin"]);
  assert.deepEqual([...spec.writeRoles], ["super_admin", "admin"]);
  assert.equal(spec.allowDelete, undefined);
  assert.equal(spec.fields.find(({ key }) => key === "employment_status").defaultValue, "active");
  for (const key of ["employee_code", "department", "designation"]) {
    assert.equal(spec.fields.find((field) => field.key === key).required, true);
  }
});

test("staff directory queries and writes always retain the selected branch", async () => {
  const db = client({ data: [{ id: "employee-1" }], error: null });
  globalThis.__hrTestSupabase = db;
  const api = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#staff-branch`);
  const spec = api.unifiedModules.staff;

  await api.loadUnifiedRows(spec, "branch-a");
  assert.ok(db.calls.some((call) => call[0] === "eq" && call[1] === "branch_id" && call[2] === "branch-a"));

  db.calls.length = 0;
  await api.saveUnifiedRow(spec, "branch-a", null, {
    title: "Employee",
    employee_code: "E-01",
    department: "Academic",
    designation: "Teacher",
    unrelated: "must not be persisted",
  });
  const inserted = db.calls.find((call) => call[0] === "insert")[1];
  assert.equal(inserted.branch_id, "branch-a");
  assert.equal(inserted.employee_code, "E-01");
  assert.equal("unrelated" in inserted, false);

  await assert.rejects(api.saveUnifiedRow(spec, "", null, { title: "Employee" }), /اختر الفرع/);
  await assert.rejects(api.saveUnifiedRow(spec, "branch-a", null, { title: "Employee" }), /الحقول المطلوبة/);
});
