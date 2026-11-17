const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const read = file => fs.readFileSync(path.join(root,file),'utf8');
const names = fs.readdirSync(path.join(root,'supabase/migrations')).filter(n => n.endsWith('.sql')).sort();
const phase3bProposals = [
  '20261116142308_atomic_role_management.sql',
  '20261116151509_branch_membership_write_lockdown.sql',
];
const additionalMigrations = [
  '20261110172940_sai_system_settings_shared_20261110.sql',
  '20261110173339_sai_unified_modules_web_mobile_secure.sql',
  '20261110173506_sai_unified_module_realtime.sql',
];
const baselineNames = names.filter(name => !phase3bProposals.includes(name)
  && !additionalMigrations.includes(name)
  && !name.includes('_production_'));
const service = read('supabase/migrations/20261116013951_phase2b_service_permissions.sql');
const settings = read('supabase/migrations/20261116013952_phase2b_system_settings.sql');

test('Phase 2C migration baseline remains intact beside the local Phase 3B proposal', () => {
  assert.equal(baselineNames.length, 38);
  assert.equal(new Set(baselineNames.map(n => n.split('_')[0])).size, 38);
  assert.deepEqual(baselineNames.slice(-3), ['20261116013950_learning_scored_exercises.sql',
    '20261116013951_phase2b_service_permissions.sql','20261116013952_phase2b_system_settings.sql']);
  for (const proposal of phase3bProposals) assert.ok(names.includes(proposal));
  for (const sql of [service,settings]) {
    assert.match(sql, /\bbegin;/); assert.match(sql, /commit;\s*$/);
    assert.doesNotMatch(sql.replace(/--[^\n]*/g,''), /\b(?:drop|truncate)\b|disable row level|grant all|to\s+public\b/i);
  }
});

test('column grants cover literal selects and filters of both services and existing-account linking', () => {
  const grants = new Map([...service.matchAll(/grant select \(([^)]+)\) on public\.(\w+)/g)]
    .map(([,cols,table]) => [table,new Set(cols.split(',').map(c => c.trim()))]));
  let checked = 0;
  const missing = [];
  for (const fn of ['manage-roles','provision-learning-account','link-student-account']) {
    const source = read(`supabase/functions/${fn}/index.ts`)
      + (fn === 'manage-roles' ? read('supabase/functions/_shared/role-management-handler.ts') : '');
    for (const [,table,chain] of source.matchAll(/\.from\("(\w+)"\)([^;]*?)(?=;|\.from\()/gs)) {
      const selected = [...chain.matchAll(/\.select\("([\w, ]+)"/g)].flatMap(m => m[1].split(',').map(c => c.trim()));
      const filtered = [...chain.matchAll(/\.(?:eq|neq|is|in|not|order)\("(\w+)"/g)].map(m => m[1]);
      for (const col of [...selected,...filtered]) {
        if (!grants.get(table)?.has(col)) missing.push(`${fn}: missing SELECT ${table}.${col}`);
        checked++;
      }
    }
  }
  assert.ok(checked > 100);
  assert.deepEqual(missing, []);
});

test('settings cast is procedurally guarded and audit-only authority is revoked after ownership transfer', () => {
  assert.match(settings, /if new.value_type='number' then\s+if new.value_text::integer > 3650/);
  assert.doesNotMatch(settings, /new.value_type='number' and new.value_text::integer/);
  const owner = settings.indexOf('alter function private.audit_system_setting() owner to');
  assert.ok(settings.indexOf('revoke create on schema private from sai_settings_audit_writer',owner) > owner);
  assert.ok(settings.indexOf("revoke sai_settings_audit_writer from %I",owner) > owner);
  const verification = read('supabase/tests/phase2b_read_only_verification.sql').replace(/--[^\n]*/g,'');
  assert.doesNotMatch(verification, /\b(?:insert|update|delete|grant|revoke|alter|create|drop|truncate|set)\b\s+(?:into|table|role|on|schema|function)/i);
  assert.match(verification, /m.admin_option, m.inherit_option, m.set_option/);
  assert.match(verification, /audit_writer_create_expected_false/);
});
