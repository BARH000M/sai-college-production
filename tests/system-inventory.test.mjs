import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { canAccessModule, isModuleAvailable, navigation, visibleNavigation } from '../src/portal/lib/navigation.ts';
import { expectedSystemEntryCount, systemCategories } from '../src/portal/lib/systemInventory.ts';

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
