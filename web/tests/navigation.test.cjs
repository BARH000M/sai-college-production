const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../src/lib/navigation.ts"), "utf8");
const code = stripTypeScriptTypes(source, { mode: "strip" });
const navigationModule = import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}`);

const roles = ["super_admin", "admin", "teacher", "accountant", "receptionist", "librarian", "student", "parent", "content_editor"];

test("all nine roles have a home and unknown roles have no navigation", async () => {
  const { visibleNavigation, isAppRole } = await navigationModule;
  for (const role of roles) {
    assert.equal(isAppRole(role), true);
    assert.equal(visibleNavigation([role])[0].id, "home");
  }
  assert.equal(isAppRole("owner"), false);
  assert.equal(visibleNavigation(["owner"]).length, 0);
});

test("multi-role navigation is exactly the union without duplicates", async () => {
  const { visibleNavigation } = await navigationModule;
  const union = new Set([...visibleNavigation(["teacher"]), ...visibleNavigation(["accountant"])].map((item) => item.id));
  const combined = visibleNavigation(["teacher", "accountant"]).map((item) => item.id);
  assert.equal(combined.length, union.size);
  for (const id of combined) assert.ok(union.has(id));
  assert.equal(combined.includes("admissions"), true);
  assert.equal(combined.includes("finance"), true);
});

test("student and parent cannot see administration-only sections", async () => {
  const { visibleNavigation } = await navigationModule;
  for (const role of ["student", "parent"]) {
    const ids = visibleNavigation([role]).map((item) => item.id);
    for (const id of ["admissions", "reception", "branches", "cms"]) assert.equal(ids.includes(id), false);
  }
});

test("navigation matches the approved prototype role mapping", async () => {
  const { navigation } = await navigationModule;
  const prototype = JSON.parse(fs.readFileSync(path.join(__dirname, "../../prototype/SAI-College-Redesigned-App/docs/role-module-map.json"), "utf8"));
  assert.equal(navigation.length, prototype.modules.length + 2);
  assert.equal(new Set(navigation.map((item) => item.id)).size, navigation.length);
  for (const module of prototype.modules) {
    const actual = navigation.find((item) => item.id === module.id);
    assert.ok(actual, module.id);
    const expected = module.id === "admissions" ? [...module.roles, "teacher"]
      : module.id === "finance" ? [...module.roles, "receptionist"] : module.roles;
    assert.deepEqual([...actual.roles].sort(), [...expected].sort(), module.id);
  }
});
