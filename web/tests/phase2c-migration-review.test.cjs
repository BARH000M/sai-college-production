const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const read = file => fs.readFileSync(path.join(root,file),'utf8');
const names = fs.readdirSync(path.join(root,'supabase/migrations')).filter(n => n.endsWith('.sql')).sort();
const phase3bProposals = [
  '20261116142308_atomic_role_management.sql',
  '20261116151509_branch_membership_write_lockdown.sql',
];
const reviewed = [
  ['20261116013950_learning_scored_exercises.sql', '2eb8cb5c25dfb95c4d636a5e8b76653a64931c7493d242f172effd7dc1e83e90'],
  ['20261116013951_phase2b_service_permissions.sql', 'f5d38fc2f3413f24cf29393411f947701a16354b2810fb401801a39be731ce28'],
  ['20261116013952_phase2b_system_settings.sql', '88c5595cca3ef84a5919002183d33dcee8d1c60f87de8cd162d10f639c014bb7'],
  ['20261116142308_atomic_role_management.sql', '41f66351904fe1dbfc1b83ef561a96b60d93cff182a5560a9a0cd2ff666b8fe4'],
  ['20261116151509_branch_membership_write_lockdown.sql', '4241b03060366b2743ca50e567f98a6a8f191689982eae9897709c5eccd656a8'],
];
const service = read('supabase/migrations/20261116013951_phase2b_service_permissions.sql');
const settings = read('supabase/migrations/20261116013952_phase2b_system_settings.sql');

test('Main migration proposals remain separate from the Phase 2C baseline', () => {
  assert.equal(new Set(names.map(n => n.split('_')[0])).size, names.length);
  const lock = JSON.parse(read('supabase/deployment/phase7m/migration-lock.json'));
  const locked = new Map(lock.migrations.map(migration => [migration.filename, migration]));
  assert.equal(locked.size, lock.migrations.length, 'migration lock contains duplicate filenames');
  assert.deepEqual([...locked.keys()].sort(), names, 'migration files and lock inventory differ');
  for (const name of names) {
    const entry = locked.get(name);
    const version = name.split('_')[0];
    assert.equal(entry.version, version, `${name} version differs from the lock`);
    const normalized = fs.readFileSync(path.join(root, 'supabase/migrations', name))
      .toString('utf8').replace(/\r\n/g, '\n');
    assert.equal(crypto.createHash('sha256').update(normalized).digest('hex'), entry.sha256_lf,
      `${name} checksum differs from the lock`);
  }
  let previous = -1;
  for (const [name, expectedHash] of reviewed) {
    const index = names.indexOf(name);
    assert.ok(index > previous, `${name} is missing or out of historical order`);
    previous = index;
    const entry = locked.get(name);
    assert.equal(entry?.sha256_lf, expectedHash, `${name} lock checksum changed`);
  }
  assert.deepEqual(reviewed.slice(-2).map(([name]) => name), phase3bProposals);
  const manifest = JSON.parse(read('supabase/deployment/phase7r/main-deployment-manifest.json'));
  assert.equal(manifest.reconciliation.release_ready, false);
  const deploymentSteps = [...manifest.steps, ...manifest.deferred_steps];
  const completedSteps = new Set();
  for (const step of deploymentSteps) {
    for (const dependency of step.depends_on) {
      assert.ok(completedSteps.has(dependency), `${step.id} has a missing or unordered dependency: ${dependency}`);
    }
    completedSteps.add(step.id);
  }
  for (const item of [...manifest.required_source_files, ...deploymentSteps]) {
    assert.doesNotMatch(item.path || '', /phase4b/i);
  }
  const pinnedPaths = new Set(manifest.required_source_files.map(item => item.path));
  for (const step of deploymentSteps.filter(item => item.kind === 'sql')) {
    assert.ok(pinnedPaths.has(step.path), `${step.id} references an unpinned deployment package`);
  }
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
