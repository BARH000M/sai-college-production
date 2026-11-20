const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../../src/portal/lib/navigation.ts"), "utf8");
const code = stripTypeScriptTypes(source, { mode: "strip" });
const navigationModule = import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}`);

const allRoles = ["super_admin", "admin", "teacher", "accountant", "receptionist", "librarian", "student", "parent", "content_editor"];
const idsFor = (visibleNavigation, roles) => visibleNavigation(roles).map((item) => item.id);

test("the nine approved roles are unchanged and unknown roles never resolve", async () => {
  const { roleLabels, isAppRole } = await navigationModule;
  assert.deepEqual(Object.keys(roleLabels).sort(), [...allRoles].sort());
  assert.equal(isAppRole("owner"), false);
  assert.equal(isAppRole("super-admin"), false);
});

test("a global OFF hides the module for every role even when a role override allows it", async () => {
  const { applyModuleToggles, isModuleEnabledFor, isModuleDisabled, visibleNavigation } = await navigationModule;
  applyModuleToggles(["finance"], { finance: { accountant: true, admin: true, parent: true, student: true } });

  assert.equal(isModuleDisabled("finance"), true);
  for (const role of ["super_admin", "admin", "accountant", "parent", "student", "receptionist"]) {
    assert.equal(isModuleEnabledFor("finance", [role]), false, `${role} must not bypass a global OFF`);
    assert.equal(idsFor(visibleNavigation, [role]).includes("finance"), false, role);
  }
  // A multi-role account cannot bypass it either.
  assert.equal(idsFor(visibleNavigation, ["accountant", "admin"]).includes("finance"), false);
  applyModuleToggles([], {});
});

test("a per-role override narrows a globally enabled module and inherit restores it", async () => {
  const { applyModuleToggles, isModuleEnabledFor, moduleRoleOverride, visibleNavigation } = await navigationModule;
  applyModuleToggles([], { finance: { student: false } });

  assert.equal(moduleRoleOverride("finance", "student"), false);
  assert.equal(moduleRoleOverride("finance", "parent"), null);
  assert.equal(isModuleEnabledFor("finance", ["student"]), false);
  assert.equal(isModuleEnabledFor("finance", ["parent"]), true);
  assert.equal(isModuleEnabledFor("finance", ["admin"]), true);
  assert.equal(idsFor(visibleNavigation, ["student"]).includes("finance"), false);
  assert.equal(idsFor(visibleNavigation, ["parent"]).includes("finance"), true);

  // Removing the row (inherit) returns the role to the global state.
  applyModuleToggles([], {});
  assert.equal(moduleRoleOverride("finance", "student"), null);
  assert.equal(idsFor(visibleNavigation, ["student"]).includes("finance"), true);
});

test("multi-role accounts get the union while an override never grants an unmapped role", async () => {
  const { applyModuleToggles, canAccessModule, isModuleEnabledFor, visibleNavigation } = await navigationModule;
  // Student is not part of the inventory role mapping; a stray override must not grant it.
  applyModuleToggles([], { inventory: { student: true } });

  assert.equal(canAccessModule("inventory", ["student"]), false);
  assert.equal(idsFor(visibleNavigation, ["student"]).includes("inventory"), false);
  assert.equal(isModuleEnabledFor("inventory", ["student"]), true, "the toggle is on but the role is unmapped");

  // The mapped role still inherits the global ON, and the union keeps it for both.
  assert.equal(idsFor(visibleNavigation, ["accountant"]).includes("inventory"), true);
  assert.equal(idsFor(visibleNavigation, ["student", "accountant"]).includes("inventory"), true);
  // A disabling override on one role does not remove the union for the other.
  applyModuleToggles([], { inventory: { accountant: false, admin: false } });
  assert.equal(idsFor(visibleNavigation, ["student", "accountant"]).includes("inventory"), true);
  applyModuleToggles([], {});
});

test("always-on modules ignore both global disables and role overrides", async () => {
  const { applyModuleToggles, alwaysOnModuleIds, isModuleAvailable, isModuleDisabled, isModuleEnabledFor, moduleRoleOverride, visibleNavigation } = await navigationModule;
  applyModuleToggles(["home", "profile", "notifications", "settings", "roles", "backups"], {
    home: { student: false },
    settings: { admin: false },
  });

  for (const id of alwaysOnModuleIds) {
    assert.equal(isModuleDisabled(id), false, `${id} must never be disabled`);
    assert.equal(isModuleAvailable(id), true, `${id} must stay reachable`);
  }
  assert.equal(moduleRoleOverride("home", "student"), null);
  assert.equal(isModuleEnabledFor("home", ["student"]), true);
  for (const role of ["super_admin", "admin"]) {
    assert.equal(idsFor(visibleNavigation, [role]).includes("settings"), true, role);
  }
  assert.equal(idsFor(visibleNavigation, ["student"]).includes("home"), true);
  applyModuleToggles([], {});
});

test("a failed toggle load never resurrects a disabled module", async () => {
  const { applyModuleToggleSnapshot, applyModuleToggles, isModuleDisabled, visibleNavigation } = await navigationModule;
  applyModuleToggles(["library"], {});
  assert.equal(idsFor(visibleNavigation, ["librarian"]).includes("library"), false);

  // The global read failed: the last known state must be preserved.
  applyModuleToggleSnapshot({ toggles: null, overrides: null });
  assert.equal(isModuleDisabled("library"), true);
  assert.equal(idsFor(visibleNavigation, ["librarian"]).includes("library"), false);

  // A successful reload clears it again.
  applyModuleToggleSnapshot({ toggles: [], overrides: [] });
  assert.equal(isModuleDisabled("library"), false);
  assert.equal(idsFor(visibleNavigation, ["librarian"]).includes("library"), true);
  applyModuleToggles([], {});
});

test("a failed override read keeps the global state and roles inherit it", async () => {
  const { applyModuleToggleSnapshot, isModuleEnabledFor, visibleNavigation } = await navigationModule;
  applyModuleToggleSnapshot({ toggles: [{ module_id: "finance", enabled: false }], overrides: null });
  assert.equal(isModuleEnabledFor("finance", ["parent"]), false);
  assert.equal(idsFor(visibleNavigation, ["parent"]).includes("finance"), false);

  applyModuleToggleSnapshot({ toggles: [{ module_id: "library", enabled: true }], overrides: null });
  assert.equal(isModuleEnabledFor("library", ["librarian"]), true);
  assert.equal(idsFor(visibleNavigation, ["librarian"]).includes("library"), true);
  applyModuleToggleSnapshot({ toggles: [], overrides: [] });
});

test("a first-load failure keeps the portal open because navigation is not the security boundary", async () => {
  const { applyModuleToggleSnapshot, isModuleDisabled, visibleNavigation } = await navigationModule;
  applyModuleToggleSnapshot({ toggles: null, overrides: null });
  assert.equal(isModuleDisabled("finance"), false);
  // Every role can still reach its own home screen; row level security still guards data.
  for (const role of allRoles) assert.equal(idsFor(visibleNavigation, [role]).includes("home"), true, role);
});

test("overrides never introduce a role outside the nine approved roles", async () => {
  const { applyModuleToggleSnapshot, isModuleEnabledFor, moduleRoleOverride } = await navigationModule;
  applyModuleToggleSnapshot({
    toggles: [{ module_id: "finance", enabled: false }],
    overrides: [{ module_id: "finance", role: "owner", enabled: true }],
  });
  assert.equal(moduleRoleOverride("finance", "owner"), null);
  assert.equal(isModuleEnabledFor("finance", ["owner"]), false);
  applyModuleToggleSnapshot({ toggles: [], overrides: [] });
});