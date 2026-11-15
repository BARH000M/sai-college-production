const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const base = path.join(__dirname, '../../src/portal/lib');
const read = name => fs.readFileSync(path.join(base, name), 'utf8');
const dataUrl = source => `data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source, { mode: 'strip' })).toString('base64')}`;
const helperUrl = dataUrl(read('functionErrors.ts'));
async function load(name, client) {
  globalThis.__previewBlockerClient = client;
  return import(dataUrl(read(name)
    .replace('import { supabase } from "./supabase";', 'const supabase = globalThis.__previewBlockerClient;')
    .replace('"./functionErrors"', JSON.stringify(helperUrl))) + `#${Math.random()}`);
}
test('function diagnostics preserve status and classify permission failure without exposing response secrets', async () => {
  const { functionFailure } = await import(helperUrl);
  const response = new Response(JSON.stringify({ message: 'permission denied for table user_roles', token: 'DO_NOT_PRINT' }), { status: 500 });
  const error = await functionFailure({ context: response }, 'manage-roles');
  assert.match(error.message, /manage-roles \(HTTP 500\)/);
  assert.match(error.message, /database_permission_denied/);
  assert.doesNotMatch(error.message, /DO_NOT_PRINT|user_roles/);
  assert.equal(response.bodyUsed, false);
  for (const status of [400, 401, 403, 404, 409, 422, 500, 502]) {
    const result = await functionFailure({ context: new Response('SECRET_HTML_OR_JWT', { status }) }, 'test');
    assert.match(result.message, new RegExp(`HTTP ${status}`));
    assert.doesNotMatch(result.message, /SECRET_HTML_OR_JWT/);
  }
  assert.doesNotMatch((await functionFailure(new Error('SECRET'), 'test')).message, /SECRET/);
});
test('all account integrations surface HTTP failures and never retry a mutation', async () => {
  for (const [file, method, args, endpoint] of [
    ['roles.ts', 'changeUserRole', ['target', 'student', true], 'manage-roles'],
    ['learningAccounts.ts', 'provisionLearningAccount', [{ studentId: 'student', kind: 'student', email: 'test@example.test' }], 'provision-learning-account'],
    ['studentAccounts.ts', 'linkStudentAccount', ['student', 'target'], 'link-student-account'],
  ]) {
    let calls = 0;
    const api = await load(file, { functions: { invoke: async name => {
      assert.equal(name, endpoint); calls++;
      return { data: null, error: { context: new Response('{"message":"permission denied for table user_roles"}', { status: 500 }) } };
    } } });
    await assert.rejects(api[method](...args), /HTTP 500.*database_permission_denied/);
    assert.equal(calls, 1);
  }
});
test('settings missing backend has an explicit unavailable error, distinct from RLS denial', async () => {
  for (const code of ['PGRST205', '42P01', '42501']) {
    const api = await load('systemSettings.ts', { from: () => ({ select: () => ({ eq: () => ({ order: async () => ({ data: null, error: { code, message: 'denied' } }) }) }) }) });
    await assert.rejects(api.loadSettings('general'), code === '42501' ? /settings_access_denied/ : /settings_backend_unavailable/);
  }
});
test('settings cannot display save controls after failed load or save a stale category', () => {
  const source = fs.readFileSync(path.join(base, '../pages/SystemSettings.tsx'), 'utf8');
  assert.match(source, /loadedCategory === section.category && !loading && !error/);
  assert.match(source, /if \(!privileged \|\| !ready \|\| saving !== null\) return/);
  assert.match(source, /\{ready && <div/);
});
