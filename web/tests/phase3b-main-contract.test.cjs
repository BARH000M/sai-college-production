const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');

test('every executable Edge role writer uses the reviewed contract', () => {
  const directory = path.join(root, 'supabase/functions');
  const visit = p => fs.readdirSync(p, { withFileTypes: true }).flatMap(e => e.isDirectory() ? visit(path.join(p, e.name)) : [path.join(p, e.name)]);
  for (const file of visit(directory).filter(p => p.endsWith('.ts') && !p.endsWith('_test.ts'))) {
    const code = fs.readFileSync(file, 'utf8');
    // Fail if a future handler restores direct service role writes, including
    // a separately assigned builder followed by DML before the next semicolon.
    for (const match of code.matchAll(/\.from\(["']user_roles["']\)([^;]*)/gs)) {
      assert.doesNotMatch(match[1], /\.(?:insert|upsert|update|delete)\(/, path.relative(root, file));
    }
  }
  const school = read('supabase/functions/school-admin/index.ts');
  assert.match(school, /action === 'grant-role' \|\| action === 'revoke-role'/);
  assert.match(school, /await handleManageRoles\(new Request/);
  const provision = read('supabase/functions/provision-learning-account/index.ts');
  assert.doesNotMatch(provision, /auth\.admin\.(?:createUser|deleteUser)\(/);
  assert.match(provision, /rpc\("sai_manage_teacher_assignment"/);
});

test('the reviewed forward package does not mutate historical settings or migration history', () => {
  const folder = path.join(root, 'supabase/deployment/phase3b-main');
  const files = fs.readdirSync(folder).filter(n => /^0\d_.*\.sql$/.test(n)).sort();
  assert.deepEqual(files, ['01_role_contract.sql', '02_teacher_assignment.sql', '03_verified_onboarding.sql']);
  const sql = files.map(n => fs.readFileSync(path.join(folder, n), 'utf8')).join('\n');
  assert.doesNotMatch(sql, /(?:insert\s+into|update|delete\s+from|alter\s+table|drop\s+table)\s+(?:public\.)?sai_system_settings/i);
  assert.doesNotMatch(sql, /supabase_migrations|disable row level|delete from public\.audit_logs|truncate\s+(?:table\s+)?public\./i);
  assert.match(sql, /revoke insert,update,delete,truncate on public\.user_roles from public,anon,authenticated,service_role/);
  assert.match(sql, /create trigger sai_guard_last_super_admin/);
  assert.match(sql, /for share/);
});
