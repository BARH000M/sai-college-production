const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const LIB = path.join(__dirname, "../../src/portal/lib");

function toDataUrl(source) {
  const code = stripTypeScriptTypes(source, { mode: "strip" });
  return `data:text/javascript;base64,${Buffer.from(code).toString("base64")}`;
}

async function loadModule(file, dependencies = {}) {
  let source = fs.readFileSync(path.join(LIB, file), "utf8");
  for (const [specifier, url] of Object.entries(dependencies)) {
    source = source.replace(`from "${specifier}"`, `from "${url}"`);
  }
  return import(toDataUrl(source));
}

const navigationUrl = toDataUrl(fs.readFileSync(path.join(LIB, "navigation.ts"), "utf8"));
const registryUrl = toDataUrl(fs.readFileSync(path.join(LIB, "portalRegistry.ts"), "utf8"));
const navigationModule = import(navigationUrl);
const sidebarModule = loadModule("sidebarSections.ts", { "./navigation": navigationUrl, "./portalRegistry": registryUrl });
const langModule = loadModule("portalLang.ts");

const ROLES = [
  "super_admin", "admin", "teacher", "accountant", "receptionist",
  "librarian", "student", "parent", "content_editor",
];

function reset(nav) {
  nav.applyModuleToggles([], {});
}

test("all nine role mappings are preserved", async () => {
  const nav = await navigationModule;
  reset(nav);
  const { roleLabels, navigation, visibleNavigation } = nav;
  assert.deepEqual(Object.keys(roleLabels).sort(), [...ROLES].sort());
  assert.equal(new Set(navigation.map((item) => item.id)).size, navigation.length);
  for (const role of ROLES) {
    assert.ok(visibleNavigation([role]).length > 0, `${role} must reach at least one module`);
  }
  assert.ok(navigation.every((item) => item.roles.length > 0), "every module has at least one approved role");
});

test("a global OFF cannot be bypassed by a per-role ON override", async () => {
  const nav = await navigationModule;
  reset(nav);
  nav.applyModuleToggles(["finance"], { finance: { accountant: true, super_admin: true } });
  assert.equal(nav.isModuleEnabledFor("finance", ["accountant"]), false);
  assert.equal(nav.isModuleEnabledFor("finance", ["super_admin"]), false);
  assert.equal(nav.visibleNavigation(["accountant"]).some((item) => item.id === "finance"), false);
  assert.equal(nav.moduleRoleOverride("finance", "accountant"), true, "the override row is retained but never wins");
  reset(nav);
});

test("a per-role OFF hides the module only for that role", async () => {
  const nav = await navigationModule;
  reset(nav);
  nav.applyModuleToggles([], { library: { teacher: false } });
  assert.equal(nav.isModuleEnabledFor("library", ["teacher"]), false);
  assert.equal(nav.isModuleEnabledFor("library", ["librarian"]), true);
  assert.equal(nav.visibleNavigation(["teacher"]).some((item) => item.id === "library"), false);
  assert.equal(nav.visibleNavigation(["librarian"]).some((item) => item.id === "library"), true);
  reset(nav);
});

test("multi-role accounts get the union and only hide when every role denies", async () => {
  const nav = await navigationModule;
  reset(nav);
  nav.applyModuleToggles([], { library: { teacher: false, librarian: false } });
  assert.equal(nav.isModuleEnabledFor("library", ["teacher", "librarian"]), false);
  assert.equal(nav.isModuleEnabledFor("library", ["teacher", "accountant"]), true, "an inheriting role keeps the module");
  reset(nav);
});

test("always-on modules cannot be disabled by global state or overrides", async () => {
  const nav = await navigationModule;
  reset(nav);
  nav.applyModuleToggles([...nav.alwaysOnModuleIds], { home: { teacher: false }, roles: { admin: false } });
  for (const id of nav.alwaysOnModuleIds) {
    assert.equal(nav.isModuleEnabledFor(id, ["teacher"]), true, `${id} must stay enabled`);
    assert.equal(nav.isModuleDisabled(id), false, `${id} must never be reported disabled`);
  }
  reset(nav);
});

test("overrides for roles outside the nine approved roles are ignored", async () => {
  const nav = await navigationModule;
  reset(nav);
  nav.applyModuleToggles([], { finance: { owner: false, guest: true } });
  assert.equal(nav.isModuleEnabledFor("finance", ["owner"]), true);
  assert.equal(nav.moduleRoleOverride("finance", "owner"), null);
  reset(nav);
});

test("a failed toggle load keeps the last applied state instead of clearing it", async () => {
  const nav = await navigationModule;
  reset(nav);
  nav.applyModuleToggles(["inventory"], { inventory: { admin: false } });
  assert.equal(nav.isModuleDisabled("inventory"), true);

  // A transient failure (null toggles) must not resurrect the module.
  nav.applyModuleToggleSnapshot({ toggles: null, overrides: null });
  assert.equal(nav.isModuleDisabled("inventory"), true);
  assert.equal(nav.isModuleEnabledFor("inventory", ["admin"]), false);
  reset(nav);
});

test("a snapshot filters unknown roles and keeps the global state authoritative", async () => {
  const nav = await navigationModule;
  reset(nav);
  nav.applyModuleToggleSnapshot({
    toggles: [
      { module_id: "transport", enabled: false },
      { module_id: "library", enabled: true },
    ],
    overrides: [
      { module_id: "transport", role: "student", enabled: true },
      { module_id: "transport", role: "intruder", enabled: true },
      { module_id: "library", role: "teacher", enabled: false },
    ],
  });
  assert.equal(nav.isModuleEnabledFor("transport", ["student"]), false, "global OFF wins");
  assert.equal(nav.moduleRoleOverride("transport", "intruder"), null, "unknown roles are dropped");
  assert.equal(nav.isModuleEnabledFor("library", ["teacher"]), false);
  assert.equal(nav.isModuleEnabledFor("library", ["student"]), true);
  reset(nav);
});

test("toggleable modules exclude the always-on safeguards", async () => {
  const nav = await navigationModule;
  reset(nav);
  const toggleable = nav.toggleableModules().map((item) => item.id);
  for (const id of nav.alwaysOnModuleIds) assert.equal(toggleable.includes(id), false, `${id} is always on`);
  assert.ok(toggleable.length > 0);
  assert.equal(new Set(toggleable).size, toggleable.length, "no duplicate module ids");
});

test("sidebar zones cover exactly the modules a role can open", async () => {
  const nav = await navigationModule;
  const sidebar = await sidebarModule;
  reset(nav);

  const zoneIds = new Set(sidebar.sidebarZones.map((zone) => zone.id));
  for (const section of sidebar.visibleSidebarSections(["super_admin"])) {
    assert.ok(zoneIds.has(section.zone), `${section.id} must belong to a known zone`);
  }

  for (const role of ROLES) {
    const expected = nav.visibleNavigation([role]).map((item) => item.id).sort();
    const grouped = sidebar.groupedSidebarSections([role])
      .flatMap((group) => group.sections)
      .flatMap((section) => section.items.map((item) => item.id))
      .sort();
    assert.deepEqual(grouped, expected, `${role} sidebar must match its authorized modules`);
  }
});

test("grouped sections preserve zone order and drop empty zones", async () => {
  const sidebar = await sidebarModule;
  const groups = sidebar.groupedSidebarSections(["student"]);
  assert.ok(groups.length > 0);
  const order = groups.map((group) => sidebar.sidebarZones.findIndex((zone) => zone.id === group.zone.id));
  assert.deepEqual(order, [...order].sort((a, b) => a - b));
  for (const group of groups) assert.ok(group.sections.length > 0);
});

test("every module and section label is translated into Arabic, English and Chinese", async () => {
  const nav = await navigationModule;
  const sidebar = await sidebarModule;
  const lang = await langModule;

  assert.deepEqual(lang.portalLanguages.map((item) => item.id), ["ar", "en", "zh"]);
  assert.equal(lang.directionFor("ar"), "rtl");
  assert.equal(lang.directionFor("en"), "ltr");
  assert.equal(lang.directionFor("zh"), "ltr");

  for (const item of nav.navigation) {
    const entry = lang.navLabels[item.id];
    assert.ok(entry, `nav label missing for ${item.id}`);
    for (const value of entry) assert.ok(value.trim().length > 0, `${item.id} has an empty translation`);
  }

  for (const section of sidebar.visibleSidebarSections(["super_admin"])) {
    const entry = lang.sectionLabels[section.id];
    assert.ok(entry, `section label missing for ${section.id}`);
    for (const value of entry) assert.ok(value.trim().length > 0);
  }

  for (const zone of sidebar.sidebarZones) {
    assert.ok(lang.zoneLabels[zone.id], `zone label missing for ${zone.id}`);
  }
});