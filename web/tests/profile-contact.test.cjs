const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const source = fs.readFileSync(path.join(__dirname, '../../src/portal/lib/profile.ts'), 'utf8')
  .replace('import { supabase } from "./supabase";', 'const supabase = globalThis.__profileClient;');
const code = stripTypeScriptTypes(source, { mode: 'strip' });
async function load(client) {
  globalThis.__profileClient = client;
  return import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}#${Math.random()}`);
}
function mock({ denied = false, missing = false, fail = false } = {}) {
  let row = { id: 'own', full_name: 'اسم أصلي', phone: null, preferred_locale: 'ar', email: 'own@example.test' };
  const calls = [];
  return { calls, from(table) {
    assert.equal(table, 'profiles');
    let updates, id;
    const result = () => {
      if (fail) return { data: null, error: { message: 'offline' } };
      if (missing || id !== 'own') return { data: updates ? [] : null, error: null };
      if (updates) { if (denied) return { data: [], error: null }; row = { ...row, ...updates }; }
      return { data: updates ? [row] : row, error: null };
    };
    return {
      update(value) { calls.push(value); updates = value; return this; },
      eq(column, value) { assert.equal(column, 'id'); id = value; return this; },
      select() { return this; },
      maybeSingle: async () => result(),
      then(resolve) { return Promise.resolve(result()).then(resolve); },
    };
  } };
}
test('own contact saves, reloads and writes only Main-permitted fields', async () => {
  const client = mock(); const api = await load(client);
  await api.saveMyProfile('own', { fullName: '  مستخدم جديد  ', phone: ' +967 777 123 456 ', locale: 'en' });
  assert.deepEqual(client.calls, [{ full_name: 'مستخدم جديد', phone: '+967 777 123 456', preferred_locale: 'en' }]);
  const profile = await api.loadMyProfile('own');
  assert.equal(profile.fullName, 'مستخدم جديد'); assert.equal(profile.locale, 'en');
  assert.equal(profile.email, 'own@example.test');
  await api.saveMyProfile('own', { fullName: 'مستخدم جديد', phone: ' ', locale: 'ar' });
  assert.equal((await api.loadMyProfile('own')).phone, null);
});
test('invalid contacts never send a mutation', async () => {
  const client = mock(); const api = await load(client);
  const valid = { fullName: 'مستخدم', phone: '', locale: 'ar' };
  for (const values of [
    { ...valid, fullName: 'x' }, { ...valid, fullName: '中'.repeat(121) },
    { ...valid, fullName: 'Name\nInjected' }, { ...valid, phone: '+()---' },
    { ...valid, phone: '1'.repeat(33) }, { ...valid, locale: 'xx' },
  ]) await assert.rejects(api.saveMyProfile('own', values));
  await assert.rejects(api.saveMyProfile('', valid)); assert.equal(client.calls.length, 0);
});
test('permission, session ownership and network failures cannot report success', async () => {
  for (const client of [mock({ denied: true }), mock({ missing: true }), mock({ fail: true })]) {
    const api = await load(client);
    await assert.rejects(api.saveMyProfile('own', { fullName: 'Valid Name', phone: '', locale: 'ar' }));
  }
  const api = await load(mock());
  await assert.rejects(api.saveMyProfile('other', { fullName: 'Valid Name', phone: '', locale: 'ar' }));
  assert.equal(await api.loadMyProfile('other'), null);
});
