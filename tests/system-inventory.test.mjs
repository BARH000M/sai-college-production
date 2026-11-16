import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { canAccessModule, isModuleAvailable, navigation, visibleNavigation } from '../src/portal/lib/navigation.ts';
import { expectedSystemEntryCount, inventoryRelatedModulePath, systemCategories } from '../src/portal/lib/systemInventory.ts';
import { inventoryReference } from '../src/portal/lib/systemInventoryEntries.ts';

const root = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root), 'utf8');

test('system inventory matches the 32-category and 147-entry reference totals', () => {
  assert.equal(systemCategories.length, 32);
  assert.equal(expectedSystemEntryCount, 147);
  assert.equal(new Set(systemCategories.map((category) => category.id)).size, 32);
  const knownIds = new Set(navigation.map((item) => item.id));
  for (const category of systemCategories) {
    for (const moduleId of category.moduleIds) {
      assert.ok(knownIds.has(moduleId), `${category.name} references an unknown module: ${moduleId}`);
    }
  }
});

test('all reference entries match the original Arabic inventory in category order', () => {
  const source = read('docs/requirements/SYSTEM_MENU_INVENTORY_32_CATEGORIES.md').replace(/\r\n/g, '\n');
  const categories = [...source.matchAll(/^## (\d\d) ـ .*\n([\s\S]*?)(?=\n## |\n---|(?![\s\S]))/gm)];
  assert.equal(categories.length, 32);
  assert.equal(inventoryReference.length, systemCategories.length);
  assert.equal(inventoryReference.reduce((total, category) => total + category.entries.length, 0), 147);
  categories.forEach((category, index) => {
    const labels = [...category[2].matchAll(/^\d+\. (.*)$/gm)].map((match) => match[1].trim());
    assert.equal(inventoryReference[index].entries.length, systemCategories[index].expectedEntries);
    assert.deepEqual(inventoryReference[index].entries.map((entry) => entry.ar), labels);
  });
});

test('inventory links are related, enabled and authorized for the existing catalog route', () => {
  const paths = new Set(visibleNavigation(['super_admin']).map((item) =>
    item.id === 'home' ? '/portal/dashboard' : item.id === 'profile' ? '/portal/profile' : `/portal/modules/${item.id}`));
  for (const entry of inventoryReference.flatMap((category) => category.entries)) {
    const path = inventoryRelatedModulePath(entry);
    assert.ok(['implemented', 'partial', 'pending'].includes(entry.status));
    if (entry.status === 'pending') assert.equal(path, null, `${entry.ar} must not link to an unfinished module`);
    if (path) assert.ok(paths.has(path), `${entry.ar} links to an unavailable route: ${path}`);
  }
  const catalog = navigation.find((item) => item.id === 'systemCatalog');
  assert.ok(catalog);
  assert.ok(paths.has('/portal/modules/systemCatalog'));
  for (const role of ['admin', 'teacher', 'accountant', 'receptionist', 'librarian', 'student', 'parent', 'content_editor']) {
    assert.equal(canAccessModule('systemCatalog', [role]), false, role);
  }
  assert.match(read('src/portal/pages/ModuleEntry.tsx'), /item\.id === "systemCatalog".*<SystemInventory/);
  assert.match(read('src/portal/pages/home/SuperAdminOverview.tsx'), /to="\/portal\/modules\/systemCatalog"/);
  assert.match(read('src/portal/pages/SystemInventory.tsx'), /inventoryReference\.map/);
});

test('the Super Administrator can open every available module and the catalog is restricted', () => {
  const available = visibleNavigation(['super_admin']);
  assert.ok(available.length > 20);
  for (const item of navigation.filter((entry) => isModuleAvailable(entry.id))) {
    assert.ok(available.some((visible) => visible.id === item.id), `Unavailable to Super Admin: ${item.id}`);
  }
  assert.equal(canAccessModule('systemCatalog', ['super_admin']), true);
  assert.equal(canAccessModule('systemCatalog', ['admin']), false);
  assert.equal(canAccessModule('systemCatalog', ['student']), false);
});

test('unimplemented skill pages are unavailable and described as pending', () => {
  const navigationSource = read('src/portal/lib/navigation.ts');
  for (const id of ['listening', 'speaking', 'tones', 'handwriting', 'reading', 'review']) {
    assert.equal(isModuleAvailable(id), false, `${id} must not expose a placeholder page`);
    assert.ok(navigationSource.includes(`id: "${id}"`));
    assert.ok(navigationSource.includes(`{ id: "${id}"`));
  }
});

test('personal attendance uses an exact student scope and verified guardian links', () => {
  const attendance = read('src/portal/lib/attendance.ts');
  const home = read('src/portal/lib/home.ts');
  const personalQuery = attendance.slice(
    attendance.indexOf('export async function loadPersonalAttendance'),
    attendance.indexOf('export async function loadAttendanceSessions'),
  );
  const parentQuery = home.slice(home.indexOf('export async function loadParentChildren'));
  const studentQuery = home.slice(home.indexOf('export async function loadStudentRecord'));
  assert.match(personalQuery, /\.eq\("student_id", studentId\)/);
  assert.match(personalQuery, /\.in\("id", sessionIds\)/);
  assert.match(parentQuery, /\.eq\("parent_user_id", userId\)/);
  assert.match(parentQuery, /\.not\("verified_at", "is", null\)/);
  assert.match(studentQuery, /\.eq\("user_id", userId\)/);
});
