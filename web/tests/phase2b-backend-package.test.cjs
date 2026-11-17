const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const files = fs.readdirSync(path.join(root, 'supabase/migrations'));
const service = read(`supabase/migrations/${files.find(f => f.endsWith('_phase2b_service_permissions.sql'))}`);
const settings = read(`supabase/migrations/${files.find(f => f.endsWith('_phase2b_system_settings.sql'))}`);
async function api(client = {}) {
  globalThis.__settingsPackageClient = client;
  const source = read('src/portal/lib/systemSettings.ts').replace('import { supabase } from "./supabase";', 'const supabase = globalThis.__settingsPackageClient;');
  return import(`data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source, { mode: 'strip' })).toString('base64')}#${Math.random()}`);
}

test('service privilege proposal has the exact operation surface, without privilege shortcuts', () => {
  assert.doesNotMatch(service, /grant\s+all|on\s+all\s+tables|to\s+(?:public|anon|authenticated)\b|security\s+definer|disable\s+row|grant\s+execute/i);
  const statements = service.replace(/--[^\n]*/g, '').split(';').map(s => s.trim()).filter(Boolean);
  assert.equal(statements[0], 'begin'); assert.equal(statements.at(-1), 'commit');
  const expectedReads = {
    user_roles: ['user_id','role'], profiles: ['id','full_name','email'], branches: ['id','name','is_active'],
    branch_memberships: ['user_id','branch_id','is_active'], students: ['id','full_name','admission_no','class_id','user_id','status','branch_id'],
    parent_student_links: ['parent_user_id','student_id','verified_at'], classes: ['id','name','program','branch_id','teacher_id','is_active'],
    academic_sessions: ['id'], learning_courses: ['id','class_id','teacher_id','title','is_active','branch_id'],
    learning_lessons: ['id','is_published','content_path','content_body','content_url','content_kind'],
    learning_lesson_progress: ['lesson_id','status'], learning_homework: ['id','course_id'],
    learning_homework_submissions: ['id','homework_id','status'], admissions_enquiries: ['id','status'],
  };
  const reads = [...service.matchAll(/grant select \(([^)]+)\) on public\.(\w+) to service_role;/g)];
  assert.equal(reads.length, Object.keys(expectedReads).length);
  for (const [, columns, table] of reads) assert.deepEqual(columns.split(',').map(c => c.trim()), expectedReads[table]);
  assert.equal(statements.length, 21); // begin + 14 reads + 5 writes + commit
  assert.match(service, /grant insert \(user_id, role, assigned_by\), delete on public.user_roles/);
  assert.match(service, /grant update \(teacher_id\) on public.classes, public.learning_courses/);
  assert.doesNotMatch(service, /grant update[^;]*user_roles|grant (?:insert|update|delete)[^;]*(?:students|parent_student_links|fee_)/);
});

test('settings proposal matches all client definitions and guards privileged access and trusted audit', async () => {
  const { settingsSections } = await api();
  const encoded = /select '([^']+)'::jsonb -> p_category -> p_key/.exec(settings)[1];
  const definitions = JSON.parse(encoded);
  assert.equal(Object.keys(definitions).length, 16);
  for (const section of settingsSections) {
    assert.deepEqual(Object.keys(definitions[section.category]), section.fields.map(f => f.key));
    for (const field of section.fields) {
      const d = definitions[section.category][field.key];
      assert.equal(d.type, field.type ?? 'text'); assert.equal(d.sensitive, !!section.superOnly);
      assert.deepEqual(d.options, field.options);
    }
  }
  assert.match(settings, /check \(scope = 'global'\)/);
  assert.match(settings, /enable row level security/g);
  assert.match(settings, /settings_super_update[\s\S]*?using \(\(select private.sai_security_has_role\('super_admin'/);
  assert.match(settings, /with check \(\(select private.sai_security_has_role\('super_admin'/);
  assert.match(settings, /and not \(private.sai_setting_definition\(category,setting_key\)->>'sensitive'\)::boolean/);
  assert.match(settings, /nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls/);
  assert.match(settings, /tg_table_schema<>'public'.*tg_table_name<>'sai_system_settings'/);
  assert.match(settings, /owner to sai_settings_audit_writer/);
  assert.match(settings, /revoke create on schema private from sai_settings_audit_writer/);
  assert.doesNotMatch(settings, /grant (?:update|delete)[^;]*sai_system_settings_audit|disable row level|insert into public.sai_system_settings/i);
});

test('settings validate booleans, bounds, enums, URLs, email and credential patterns before writing', async () => {
  let calls = 0;
  const a = await api({ from: () => { calls++; throw Error('unexpected write'); } });
  const get = (category, key) => { const s = a.settingsSections.find(s => s.category === category); return [s, s.fields.find(f => f.key === key)]; };
  for (const [cat, key, value] of [
    ['notifications','push_enabled','yes'], ['backups','retention_days',''], ['backups','retention_days','3651'],
    ['backups','retention_days','1.5'], ['printing','paper_size','A3'], ['general','contact_email','invalid'],
    ['general','website_url','http://example.test'], ['general','website_url','https://user:pass@example.test'],
    ['general','college_name','sb_secret_example'], ['general','college_name','Bearer hidden'],
  ]) await assert.rejects(a.saveSetting(...get(cat,key), value));
  assert.equal(calls, 0);
  assert.equal(a.validateSettingValue(...get('general','college_name'), '  SAI  '), 'SAI');
  assert.equal(a.validateSettingValue(...get('general','website_url'), 'https://example.test/path'), 'https://example.test/path');
  assert.equal(a.validateSettingValue(...get('notifications','push_enabled'), 'false'), 'false');
  assert.equal(a.validateSettingValue(...get('backups','retention_days'), '3650'), '3650');
});

test('settings save requires exact server acknowledgement, and missing-contract reads never become defaults', async () => {
  for (const rows of [[], [{setting_key:'wrong'}], null]) {
    const a = await api({from: () => ({upsert: () => ({select: async () => ({data:rows,error:null})})})});
    await assert.rejects(a.saveSetting(a.settingsSections[0],a.settingsSections[0].fields[0],'SAI'));
  }
  const a = await api({from: () => ({select: () => ({eq: () => ({order: async () => ({data:null,error:null})})})})});
  await assert.rejects(a.loadSettings('general'));
});

test('privileged service clients do not forward caller JWTs and authorization remains database assigned', () => {
  for (const name of ['manage-roles','provision-learning-account','link-student-account']) {
    const entry = read(`supabase/functions/${name}/index.ts`);
    const source = name === 'manage-roles'
      ? entry + read('supabase/functions/_shared/role-management-handler.ts') : entry;
    assert.match(source, /const admin = createClient\(url, serviceKey,\s*\{\s*auth:\s*\{\s*persistSession: false(?:,\s*[a-zA-Z:, ]+)?\s*\},?\s*\}\)/);
    assert.match(source, /authClient.auth.getUser\(token\)/);
    assert.match(source, /\.from\("user_roles"\)/);
    assert.doesNotMatch(source, /createClient\(url, serviceKey,[^;]*Authorization/);
    if (name === 'manage-roles') {
      assert.match(source, /auth: \{ persistSession: false, autoRefreshToken: false, detectSessionInUrl: false \}/g);
    }
    if (name !== 'link-student-account') assert.match(source, /if \(!superRole\) return json\([^\n]+403\)/);
  }
  for (const directory of ['src','mobile/lib']) {
    const visit = dir => fs.readdirSync(dir, {withFileTypes:true}).flatMap(e => e.isDirectory() ? visit(path.join(dir,e.name)) : [path.join(dir,e.name)]);
    for (const file of visit(path.join(root,directory)).filter(f => /\.(tsx?|dart)$/.test(f))) {
      assert.doesNotMatch(fs.readFileSync(file,'utf8'), /SUPABASE_SERVICE_ROLE_KEY|sb_secret_[A-Za-z0-9]{16,}/, path.relative(root,file));
    }
  }
});
