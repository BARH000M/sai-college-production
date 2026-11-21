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
const registryModule = import(registryUrl);
const sidebarLayoutUrl = toDataUrl(`
import { portalModules } from "${registryUrl}";
const empty = { order: [], hidden: [], labels: {}, icons: {}, quickLinks: [], defaultExpanded: [] };
export function currentSidebarLayout() { return empty; }
export function orderedModuleIds(order) {
  const known = order.filter((id) => portalModules.some((module) => module.id === id));
  return [...known, ...portalModules.map((module) => module.id).filter((id) => !known.includes(id))];
}
`);
const sidebarModule = loadModule("sidebarSections.ts", {
  "./navigation": navigationUrl,
  "./portalRegistry": registryUrl,
  "./sidebarLayout": sidebarLayoutUrl,
});
const langModule = loadModule("portalLang.ts");

const ROLES = [
  "super_admin", "admin", "teacher", "accountant", "receptionist",
  "librarian", "student", "parent", "content_editor",
];

function reset(nav) {
  nav.applyModuleToggles([], {});
}

test("every navigation module appears exactly once in the hierarchy", async () => {
  const nav = await navigationModule;
  const registry = await registryModule;
  const ids = registry.portalPageIds();
  assert.equal(new Set(ids).size, ids.length, "a page must be registered only once");
  assert.deepEqual([...ids].sort(), nav.navigation.map((item) => item.id).sort());
});

test("the registry keeps the reviewed module and submenu counts", async () => {
  const registry = await registryModule;
  assert.equal(registry.portalModules.length, 24);
  const submenus = registry.portalModules.reduce((sum, module) => sum + module.submenus.length, 0);
  assert.equal(submenus, 50);
  for (const module of registry.portalModules) assert.ok(module.submenus.length > 0, `${module.id} needs a submenu`);
  for (const module of registry.portalModules) {
    for (const submenu of module.submenus) assert.ok(submenu.pages.length > 0, `${module.id}/${submenu.id} needs a page`);
  }
});

test("every page resolves to a module owned by a single main module", async () => {
  const registry = await registryModule;
  const nav = await navigationModule;
  const byId = new Map(nav.navigation.map((item) => [item.id, item]));
  const owners = new Map();

  for (const module of registry.portalModules) {
    for (const submenu of module.submenus) {
      for (const page of submenu.pages) {
        const item = byId.get(page.moduleId);
        assert.ok(item, `${page.moduleId} must exist in the navigation catalogue`);
        assert.ok(item.roles.length > 0, `${page.moduleId} must keep its approved role mapping`);
        assert.equal(owners.has(page.moduleId), false, `${page.moduleId} is registered twice`);
        owners.set(page.moduleId, module.id);
        assert.equal(registry.portalModuleForPage(page.moduleId)?.id, module.id);
        assert.equal(registry.portalSubmenuForPage(page.moduleId)?.id, submenu.id);
      }
    }
  }
});

test("modules without a verified contract stay out of the clickable hierarchy", async () => {
  const nav = await navigationModule;
  const sidebar = await sidebarModule;
  reset(nav);
  const pending = ["quizzes", "media", "approvals", "reception"];
  for (const role of ROLES) {
    const rendered = new Set(sidebar.visibleSidebarModules([role])
      .flatMap((module) => module.sections)
      .flatMap((section) => section.items.map((item) => item.id)));
    for (const id of pending) {
      assert.equal(rendered.has(id), false, `${id} must not render for ${role} until verified`);
    }
  }
});

test("sidebar modules flatten to exactly the authorized navigation for every role", async () => {
  const nav = await navigationModule;
  const sidebar = await sidebarModule;
  reset(nav);
  for (const role of ROLES) {
    const expected = nav.visibleNavigation([role]).map((item) => item.id).sort();
    const rendered = sidebar.visibleSidebarModules([role])
      .flatMap((module) => module.sections)
      .flatMap((section) => section.items.map((item) => item.id))
      .sort();
    assert.deepEqual(rendered, expected, `${role} hierarchy must match its authorized modules`);
  }
  reset(nav);
});

test("multi-role accounts get the union of modules", async () => {
  const nav = await navigationModule;
  const sidebar = await sidebarModule;
  reset(nav);
  const teacher = sidebar.visibleSidebarModules(["teacher"]).map((module) => module.id);
  const accountant = sidebar.visibleSidebarModules(["accountant"]).map((module) => module.id);
  const combined = sidebar.visibleSidebarModules(["teacher", "accountant"]).map((module) => module.id);
  for (const id of [...teacher, ...accountant]) assert.ok(combined.includes(id), `${id} must stay visible`);
  assert.equal(new Set(combined).size, combined.length);
});

test("zone order is preserved and empty zones are dropped", async () => {
  const sidebar = await sidebarModule;
  const groups = sidebar.groupedSidebarModules(["student"]);
  assert.ok(groups.length > 0);
  const order = groups.map((group) => sidebar.sidebarZones.findIndex((zone) => zone.id === group.zone.id));
  assert.deepEqual(order, [...order].sort((a, b) => a - b));
  for (const group of groups) assert.ok(group.modules.length > 0);
});

test("global OFF still removes a module from the hierarchy", async () => {
  const nav = await navigationModule;
  const sidebar = await sidebarModule;
  reset(nav);
  nav.applyModuleToggles(["library"], { library: { librarian: true } });
  const rendered = sidebar.visibleSidebarModules(["librarian"])
    .flatMap((module) => module.sections)
    .flatMap((section) => section.items.map((item) => item.id));
  assert.equal(rendered.includes("library"), false, "a global disable cannot be bypassed in the hierarchy");
  reset(nav);
});

test("a per-role override never grants a module outside the approved role mapping", async () => {
  const nav = await navigationModule;
  const sidebar = await sidebarModule;
  reset(nav);
  // Enable "admissions" for students, who are not in its approved role list.
  nav.applyModuleToggles([], { admissions: { student: true } });
  const rendered = sidebar.visibleSidebarModules(["student"])
    .flatMap((module) => module.sections)
    .flatMap((section) => section.items.map((item) => item.id));
  assert.equal(rendered.includes("admissions"), false, "a role override must not widen the role mapping");
  // The approved roles still inherit the module.
  assert.equal(nav.isModuleEnabledFor("admissions", ["receptionist"]), true);
  reset(nav);
});

test("every module and submenu is translated into Arabic, English and Chinese", async () => {
  const registry = await registryModule;
  const lang = await langModule;

  for (const module of registry.portalModules) {
    const entry = lang.moduleLabels[module.id];
    assert.ok(entry, `module label missing for ${module.id}`);
    for (const value of entry) assert.ok(value.trim().length > 0, `${module.id} has an empty translation`);
    for (const submenu of module.submenus) {
      const submenuEntry = lang.sectionLabels[submenu.id];
      assert.ok(submenuEntry, `submenu label missing for ${submenu.id}`);
      for (const value of submenuEntry) assert.ok(value.trim().length > 0, `${submenu.id} has an empty translation`);
    }
  }

  for (const zone of registry.portalZones) {
    assert.ok(lang.zoneLabels[zone.id], `zone label missing for ${zone.id}`);
  }
  assert.equal(lang.translateModule("system", "ar"), "النظام والنسخ الاحتياطي");
  assert.equal(lang.translateModule("system", "en"), "System & backups");
  assert.equal(lang.translateSection("review", "zh"), "间隔复习");
});

test("the four V4.0 modules are wired and reachable for their approved roles", async () => {
  const nav = await navigationModule;
  const sidebar = await sidebarModule;
  reset(nav);
  const approved = {
    media: ["super_admin", "admin", "content_editor", "teacher"],
    approvals: ["super_admin", "admin", "content_editor", "teacher"],
    quizzes: ["super_admin", "admin", "teacher", "student", "content_editor"],
    reception: ["super_admin", "admin", "receptionist"],
  };
  for (const [id, roles] of Object.entries(approved)) {
    assert.ok(nav.isModuleAvailable(id), `${id} must be available`);
    assert.equal(nav.isModulePending(id), false, `${id} must no longer be pending`);
    for (const role of roles) {
      const rendered = sidebar.visibleSidebarModules([role])
        .flatMap((module) => module.sections)
        .flatMap((section) => section.items.map((item) => item.id));
      assert.ok(rendered.includes(id), `${id} must render for ${role}`);
    }
    assert.equal(nav.canAccessModule(id, ["student"]) && !roles.includes("student"), false, `${id} must not leak to student`);
  }
  assert.equal(nav.pendingModules.length, 0, "no module should remain pending after V4.0");
  reset(nav);
});

test("the completed modules map to a real page and translation in the registry", async () => {
  const registry = await registryModule;
  const lang = await langModule;
  const expected = { media: "content-studio", approvals: "content-studio", quizzes: "homework", reception: "front-office" };
  for (const [pageId, moduleId] of Object.entries(expected)) {
    assert.equal(registry.portalModuleForPage(pageId)?.id, moduleId, `${pageId} must belong to ${moduleId}`);
    assert.ok(lang.navLabels[pageId], `${pageId} needs a navigation label`);
  }
});