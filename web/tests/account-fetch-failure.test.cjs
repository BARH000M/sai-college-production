const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../../src/portal/lib');
const moduleUrl = source => `data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source, { mode: 'strip' })).toString('base64')}`;

test('account connectivity copy is Arabic and does not expose raw failures', async () => {
  const { accountErrorMessage } = await import(moduleUrl(fs.readFileSync(path.join(root, 'accountError.ts'), 'utf8')));
  for (const message of ['TypeError: Failed to fetch', 'NetworkError when attempting to fetch resource.', 'Load failed', 'request timed out']) {
    const copy = accountErrorMessage([message, message]);
    assert.match(copy, /تعذر الاتصال بالخادم مؤقتاً/);
    assert.match(copy, /إعادة المحاولة/);
    assert.match(copy, /لا تحتاج إلى تسجيل الخروج/);
    assert.doesNotMatch(copy, /TypeError|NetworkError/);
  }
  assert.match(accountErrorMessage(['permission denied SECRET']), /التحقق من صلاحياتك/);
  assert.doesNotMatch(accountErrorMessage(['permission denied SECRET']), /SECRET/);
});

test('network failures preserve session identity, fail role verification, and recover on manual restore', async () => {
  let failure = true;
  let inserts = 0;
  let sessionReads = 0;
  const session = { user: { id: 'test-user', email: 'test@example.test', email_confirmed_at: '2026-01-01' } };
  globalThis.__accountFetchClient = {
    auth: { getSession: async () => { sessionReads++; return { data: { session }, error: null }; } },
    schema: () => ({ from: table => {
      const query = {
        select() { return this; }, eq() { return this; },
        insert() { inserts++; throw new Error('must not insert after failed lookup'); },
        maybeSingle() { return this; },
        then(resolve) {
          return Promise.resolve(failure
            ? { data: null, error: { message: 'TypeError: Failed to fetch' } }
            : { data: table === 'profiles' ? { id: 'test-user', full_name: 'Test' } : [], error: null }).then(resolve);
        },
      };
      return query;
    } }),
  };
  try {
    const code = fs.readFileSync(path.join(root, 'auth.ts'), 'utf8')
      .replace('import { supabase } from "./supabase";', 'const supabase = globalThis.__accountFetchClient;');
    const auth = await import(moduleUrl(code));
    const failed = await auth.restoreAuthState();
    assert.equal(failed.status, 'signed-in');
    assert.equal(failed.userId, session.user.id);
    assert.equal(failed.rolesLoaded, false);
    assert.match(failed.rolesError, /Failed to fetch/);
    assert.equal(failed.profileLoaded, false);
    assert.equal(inserts, 0);
    assert.equal(sessionReads, 1);
    failure = false;
    const recovered = await auth.restoreAuthState();
    assert.equal(recovered.status, 'signed-in');
    assert.equal(recovered.userId, session.user.id);
    assert.equal(recovered.rolesError, null);
    assert.equal(recovered.rolesLoaded, true);
    assert.equal(recovered.profile.fullName, 'Test');
    assert.equal(sessionReads, 2);
  } finally { delete globalThis.__accountFetchClient; }
});
