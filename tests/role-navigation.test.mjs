import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const root = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root), 'utf8');
const navigation = read('src/portal/lib/navigation.ts');
const sections = read('src/portal/lib/sidebarSections.ts');
const sidebar = read('src/portal/components/RoleSidebar.tsx');
const portalHome = read('src/portal/pages/PortalHome.tsx');

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

test('specialist dashboards and protected student paths remain separate', () => {
  assert.match(portalHome, /<SpecialistHome roles=\{roles\}/);
  assert.match(portalHome, /<TeacherHome userId=\{userId\}/);
  assert.match(portalHome, /<LearnerHome roles=\{roles\} userId=\{userId\}/);
  assert.match(portalHome, /<ParentHome userId=\{userId\}/);
});
