import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { canAccessModule, roleLabels } from '../src/portal/lib/navigation.ts';
const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
test('all nine web roles retain privileged destination boundaries', () => {
  assert.equal(Object.keys(roleLabels).length, 9);
  for (const role of Object.keys(roleLabels)) {
    assert.equal(canAccessModule('settings', [role]), ['admin', 'super_admin'].includes(role), role);
    assert.equal(canAccessModule('roles', [role]), role === 'super_admin', role);
    assert.equal(canAccessModule('unknown-module', [role]), false);
  }
  assert.equal(canAccessModule('roles', ['admin', 'content_editor', 'accountant']), false);
  assert.equal(canAccessModule('roles', ['student', 'super_admin']), true);
});
for (const name of ['AcademicAffairs', 'Timetable']) {
  test(`${name} labels samples and disables simulated operations and official printing`, () => {
    const source = read(`src/portal/pages/academics/${name}.tsx`);
    assert.match(source, /data-academic-demo/);
    assert.match(source, /Demonstration only/);
    assert.doesNotMatch(source, /setNotice|setExamOverrides|setRequestOverrides|approveExam|approveRequest|PrintDoc/);
    assert.match(source, /type="button" disabled/);
    if (name === 'AcademicAffairs') assert.equal((source.match(/type="button" disabled/g) ?? []).length, 4);
  });
}
test('project MCP is exclusively Main read-only and backups are ignored', () => {
  const config = JSON.parse(read('.mcp.json'));
  assert.deepEqual(Object.keys(config.mcpServers), ['supabase-main']);
  const server = config.mcpServers['supabase-main'];
  const url = new URL(server.url);
  assert.equal(url.origin, 'https://mcp.supabase.com');
  assert.equal(url.searchParams.get('project_ref'), 'aeryusbrulqdxjdynwfh');
  assert.equal(url.searchParams.get('read_only'), 'true');
  assert.equal(server.command, undefined);
  assert.equal(server.headers, undefined);
  assert.match(read('.gitignore'), /^\.codex\/config-backups\/$/m);
});
