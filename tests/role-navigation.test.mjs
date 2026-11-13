import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { canAccessModule, navigation as navigationItems, visibleNavigation } from '../src/portal/lib/navigation.ts';
import { financePermissions } from '../src/portal/lib/finance.ts';

const root = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root), 'utf8');
const navigation = read('src/portal/lib/navigation.ts');
const sections = read('src/portal/lib/sidebarSections.ts');
const sidebar = read('src/portal/components/RoleSidebar.tsx');
const portalHome = read('src/portal/pages/PortalHome.tsx');
const moduleEntry = read('src/portal/pages/ModuleEntry.tsx');

const existingIds = new Set([...navigation.matchAll(/\bid:\s*"([\w]+)"\s*,\s*label:/g)].map((match) => match[1]));
const sectionIds = [...sections.matchAll(/moduleIds:\s*\[([^\]]*)\]/gs)]
  .flatMap((match) => [...match[1].matchAll(/"([\w]+)"/g)].map((id) => id[1]));

test('all sidebar section targets are existing SAI module IDs', () => {
  assert.ok(sectionIds.length > 20);
  for (const id of sectionIds) assert.ok(existingIds.has(id), `Missing module: ${id}`);
  assert.equal(new Set(sectionIds).size, sectionIds.length, 'A module appears in multiple sections');
});

test('navigation filters the role-assigned and available modules', () => {
  assert.match(sections, /new Map\(visibleNavigation\(roles\)/);
  assert.match(sections, /modulePath\(item\)/);
  assert.match(sidebar, /sidebarDestination\(item\)/);
});

test('administrative directories and admissions are hidden from student and teacher roles', () => {
  const visibleFor = (role) => visibleNavigation([role]).map((item) => item.id);
  for (const role of ['student', 'parent', 'teacher']) {
    assert.equal(visibleFor(role).includes('admissions'), false, `${role} must not see admissions`);
    assert.equal(visibleFor(role).includes('students'), false, `${role} must not see the student directory`);
    assert.equal(visibleFor(role).includes('classes'), false, `${role} must not see the administrative class directory`);
  }
  for (const role of ['student', 'parent']) {
    assert.equal(visibleFor(role).includes('attendance'), false, `${role} must not see the unscoped attendance register`);
  }
  assert.equal(visibleFor('teacher').includes('attendance'), true);
  assert.equal(visibleFor('receptionist').includes('admissions'), true);
  assert.equal(visibleFor('receptionist').includes('students'), true);
  assert.equal(navigationItems.find((item) => item.id === 'classes').roles.includes('teacher'), false);
  assert.equal(canAccessModule('admissions', ['teacher']), false);
  assert.equal(canAccessModule('students', ['student']), false);
  assert.equal(canAccessModule('classes', ['parent']), false);
  assert.match(moduleEntry, /canAccessModule\(item\.id, roles\)/);
});

test('receptionist cannot open finance or post payments; multi-role access remains additive', () => {
  const receptionist = visibleNavigation(['receptionist']).map((item) => item.id);
  assert.equal(receptionist.includes('finance'), false);
  assert.equal(financePermissions(['receptionist']).view, false);
  assert.equal(financePermissions(['receptionist']).postPayment, false);
  assert.equal(financePermissions(['accountant']).postPayment, true);
  assert.equal(financePermissions(['receptionist', 'accountant']).postPayment, true);
  assert.equal(visibleNavigation(['student', 'admin']).some((item) => item.id === 'admissions'), true);
});

test('specialist dashboards and protected student paths remain separate', () => {
  assert.match(portalHome, /<SpecialistHome roles=\{roles\}/);
  assert.match(portalHome, /<TeacherHome userId=\{userId\}/);
  assert.match(portalHome, /<LearnerHome roles=\{roles\} userId=\{userId\}/);
  assert.match(portalHome, /<ParentHome userId=\{userId\}/);
});
