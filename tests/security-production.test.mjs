import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { assertProductionEnvironment, verifyProductionBundle, productionUrl, securityHeaders } from '../scripts/security-production.mjs';
const env = {
  VITE_PUBLIC_SUPABASE_URL: productionUrl,
  VITE_PUBLIC_SUPABASE_ANON_KEY: 'sb_publishable_test',
  VITE_SAI_TARGET: 'production',
};
test('production build rejects wrong modes, projects and private credentials', () => {
  assert.doesNotThrow(() => assertProductionEnvironment(env));
  const legacyAnonKey = `e30.${Buffer.from(JSON.stringify({ role: 'anon', ref: 'aeryusbrulqdxjdynwfh' })).toString('base64url')}.signature`;
  assert.doesNotThrow(() => assertProductionEnvironment({ ...env, VITE_PUBLIC_SUPABASE_ANON_KEY: legacyAnonKey }));
  for (const input of [
    { ...env, VITE_PUBLIC_SUPABASE_URL: 'https://unauthorized.invalid' },
    { ...env, VITE_SAI_TARGET: 'preview' },
    { ...env, VITE_SAI_TARGET: undefined },
    { ...env, IS_PREVIEW: 'false' },
    { ...env, VITE_PRIVATE_KEY: 'forbidden' },
    { ...env, VITE_PUBLIC_SUPABASE_ANON_KEY: 'sb_secret_test' },
    { ...env, VITE_PUBLIC_SUPABASE_ANON_KEY: `e30.${Buffer.from(JSON.stringify({ role: 'anon', ref: 'foreign-project' })).toString('base64url')}.signature` },
  ]) assert.throws(() => assertProductionEnvironment(input));
  assert.throws(() => assertProductionEnvironment(env, 'preview'));
});
test('bundle gate rejects foreign hosts, missing identity, maps and private keys', () => {
  const dir = mkdtempSync(join(tmpdir(), 'sai-bundle-'));
  try {
    writeFileSync(join(dir, 'app.js'), productionUrl);
    assert.doesNotThrow(() => verifyProductionBundle(dir));
    for (const content of ['https://abcdefghijklmnopqrst.supabase.co', 'https://foreign.supabase.co', 'sb_secret_abcdefghijklmnopqrst', 'no backend']) {
      writeFileSync(join(dir, 'app.js'), content); assert.throws(() => verifyProductionBundle(dir));
    }
    writeFileSync(join(dir, 'app.js'), productionUrl); writeFileSync(join(dir, 'app.js.map'), '{}');
    assert.throws(() => verifyProductionBundle(dir));
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
test('headers restrict scripts, framing and backend connections while preserving camera scanning', () => {
  assert.match(securityHeaders['Content-Security-Policy'], /frame-ancestors 'none'/);
  assert.match(securityHeaders['Content-Security-Policy'], /script-src 'self';/);
  assert.match(securityHeaders['Content-Security-Policy'], /aeryusbrulqdxjdynwfh/);
  assert.match(securityHeaders['Content-Security-Policy'], /img-src[^;]*aeryusbrulqdxjdynwfh\.supabase\.co/);
  assert.equal(securityHeaders['Permissions-Policy'], 'camera=(self), microphone=(), geolocation=(), payment=()');
});
