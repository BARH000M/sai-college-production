const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const root = path.join(__dirname, '..', '..');

const source = fs.readFileSync(path.join(root, 'src/portal/lib/examinations.ts'), 'utf8')
  .replace('import { supabase } from "./supabase";', 'const supabase = globalThis.__examClient;');
const code = stripTypeScriptTypes(source, { mode: 'strip' });
async function load(client) {
  globalThis.__examClient = client;
  return import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}#${Math.random()}`);
}

// Minimal thenable query-builder mock recording every step.
function mock({ fail = false, rows = [], count = null } = {}) {
  const calls = [];
  function builder(table) {
    const state = { table, method: null, values: null, filters: [] };
    const result = () => fail
      ? { data: null, error: { message: 'offline' }, count: null }
      : { data: rows, error: null, count: count ?? rows.length };
    const api = {
      select(columns, opts) { state.select = columns; calls.push(state); return api; },
      insert(values) { state.method = 'insert'; state.values = values; calls.push(state); return api; },
      update(values) { state.method = 'update'; state.values = values; calls.push(state); return api; },
      eq(column, value) { state.filters.push(['eq', column, value]); return api; },
      in(column, value) { state.filters.push(['in', column, value]); return api; },
      order() { return api; },
      range() { return api; },
      returns() { return api; },
      then(resolve) { return Promise.resolve(result()).then(resolve); },
    };
    return api;
  }
  return { calls, from: (table) => builder(table), rpc: () => builder('rpc') };
}

const classItem = { id: 'c1', name: 'Class One', branch_id: 'b1', academic_session_id: 's1', teacher_id: 't1' };
const window = { id: 's1', name: '2026A', starts_on: '2026-01-01', ends_on: '2026-06-30' };
const validDraft = {
  classId: 'c1', courseId: '', subject: 'اللغة الصينية', title: 'اختبار منتصف الفصل',
  date: '2026-03-15', startTime: '09:00', endTime: '11:00', room: 'قاعة 1', maxScore: '100',
};

test('grade bands match the server contract including boundaries', async () => {
  const api = await load(mock());
  assert.equal(api.gradeForScore(90, 100), 'excellent');
  assert.equal(api.gradeForScore(89.9, 100), 'very_good');
  assert.equal(api.gradeForScore(80, 100), 'very_good');
  assert.equal(api.gradeForScore(70, 100), 'good');
  assert.equal(api.gradeForScore(60, 100), 'acceptable');
  assert.equal(api.gradeForScore(50, 100), 'weak');
  assert.equal(api.gradeForScore(49.9, 100), 'fail');
  assert.equal(api.gradeForScore(0, 100), 'fail');
  assert.equal(api.gradeForScore(null, 100), null);
  assert.equal(api.gradeForScore(100, 200), 'weak'); // ratio-based, not absolute
});

test('draft and mark validation reject bad input before any mutation', async () => {
  const api = await load(mock());
  assert.equal(api.validateExamDraft(validDraft, window), null);
  for (const bad of [
    { ...validDraft, title: 'x' },
    { ...validDraft, title: 'Name\nInjected' },
    { ...validDraft, subject: '' },
    { ...validDraft, date: '2026-13-01' },
    { ...validDraft, date: '2026-12-01' }, // outside the session window
    { ...validDraft, startTime: '11:00', endTime: '09:00' },
    { ...validDraft, maxScore: '0' },
    { ...validDraft, maxScore: 'abc' },
  ]) assert.ok(api.validateExamDraft(bad, window), JSON.stringify(bad));
  assert.equal(api.validateMark('', 100), null); // blank clears the mark
  assert.equal(api.validateMark('95', 100), null);
  assert.ok(api.validateMark('101', 100));
  assert.ok(api.validateMark('-1', 100));
  assert.ok(api.validateMark('x', 100));
});

test('state machine allows only the documented transitions', async () => {
  const api = await load(mock());
  for (const [from, allowed] of Object.entries({
    draft: ['marks_entry', 'cancelled'],
    marks_entry: ['review', 'cancelled'],
    review: ['marks_entry', 'published'],
    published: ['review'],
    cancelled: [],
  })) {
    for (const to of Object.keys(api.examStatuses)) {
      assert.equal(api.canTransition(from, to), allowed.includes(to), `${from} -> ${to}`);
    }
  }
});

test('create, transition and marks write only the Main-permitted contract', async () => {
  const client = mock({ rows: [{ id: 'e1' }], count: 1 });
  const api = await load(client);
  await api.createExam(classItem, validDraft, window);
  const insert = client.calls.find((call) => call.method === 'insert' && call.table === 'exams');
  assert.deepEqual(insert.values, {
    branch_id: 'b1', academic_session_id: 's1', class_id: 'c1', course_id: null,
    subject: 'اللغة الصينية', title: 'اختبار منتصف الفصل', exam_date: '2026-03-15',
    start_time: '09:00', end_time: '11:00', room: 'قاعة 1', max_score: 100,
  });

  await api.transitionExam({ id: 'e1', status: 'draft' }, 'marks_entry');
  const transition = client.calls.find((call) => call.method === 'update' && call.table === 'exams');
  assert.deepEqual(transition.values, { status: 'marks_entry' });
  assert.deepEqual(transition.filters, [['eq', 'id', 'e1'], ['eq', 'status', 'draft']]);
  await assert.rejects(api.transitionExam({ id: 'e1', status: 'draft' }, 'published'));

  const entry = { student_id: 'st1', full_name: 'طالب', admission_no: 'A-1', result_id: null, score: null, grade: null, note: null };
  await api.saveMark('e1', entry, '95', 'ممتاز', 100);
  const mark = client.calls.find((call) => call.method === 'insert' && call.table === 'exam_results');
  assert.deepEqual(mark.values, { exam_id: 'e1', student_id: 'st1', score: 95, note: 'ممتاز' });
  await api.saveMark('e1', { ...entry, result_id: 'r1' }, '', '', 100);
  const fix = client.calls.find((call) => call.method === 'update' && call.table === 'exam_results');
  assert.deepEqual(fix.values, { score: null, note: null });
  assert.deepEqual(fix.filters, [['eq', 'id', 'r1'], ['eq', 'exam_id', 'e1']]);

  // Invalid input never reaches the client.
  client.calls.length = 0;
  await assert.rejects(api.saveMark('e1', entry, '101', '', 100));
  await assert.rejects(api.createExam(classItem, { ...validDraft, title: 'x' }, window));
  assert.equal(client.calls.length, 0);
});

test('failed or empty writes never report success', async () => {
  const offline = await load(mock({ fail: true }));
  await assert.rejects(offline.createExam(classItem, validDraft, window));
  await assert.rejects(offline.transitionExam({ id: 'e1', status: 'draft' }, 'marks_entry'));
  const empty = await load(mock({ rows: [], count: 0 }));
  await assert.rejects(empty.transitionExam({ id: 'e1', status: 'draft' }, 'marks_entry'));
  await assert.rejects(empty.saveMark('e1', { student_id: 'st1', full_name: '', admission_no: '', result_id: 'r1', score: 1, grade: 'fail', note: null }, '2', '', 100));
});

test('web module wiring exposes the exams screen to the approved roles only', () => {
  const navigation = fs.readFileSync(path.join(root, 'src/portal/lib/navigation.ts'), 'utf8');
  const available = navigation.match(/availableModuleIds[^=]*=\s*\[([\s\S]*?)\];/)[1];
  assert.match(available, /"exams"/);
  const pending = navigation.match(/pendingModules[^=]*=\s*\[([\s\S]*?)\] as const;/)[1];
  assert.doesNotMatch(pending, /id: "exams"/);
  const entry = fs.readFileSync(path.join(root, 'src/portal/pages/ModuleEntry.tsx'), 'utf8');
  assert.match(entry, /item\.id === "exams"/);
});

test('client and SQL proposal share one contract', () => {
  const sql = fs.readFileSync(path.join(root, 'supabase/deployment/phase4a-examinations/001_examinations.sql'), 'utf8');
  const lib = fs.readFileSync(path.join(root, 'src/portal/lib/examinations.ts'), 'utf8');
  for (const object of ['public.exams (', 'public.exam_results (', 'sai_exam_roster', 'sai_exams_classes',
    "('draft','marks_entry','review','published','cancelled')", 'sai_exam_grade']) {
    assert.ok(sql.includes(object), `proposal missing ${object}`);
  }
  // Every table/RPC the client calls exists in the proposal.
  for (const call of ['sai_exams_classes', 'sai_exam_roster', '"exams"', '"exam_results"']) {
    const name = call.replaceAll('"', '');
    assert.ok(sql.includes(`public.${name}`) || sql.includes(`function public.${name}`), `proposal missing ${name}`);
  }
  // Grade codes and statuses are identical on both sides.
  for (const code of ['excellent', 'very_good', 'good', 'acceptable', 'weak', 'fail']) {
    assert.ok(sql.includes(`'${code}'`), `SQL missing grade ${code}`);
    assert.ok(lib.includes(code), `client missing grade ${code}`);
  }
  for (const status of ['draft', 'marks_entry', 'review', 'published', 'cancelled']) {
    assert.ok(sql.includes(`'${status}'`), `SQL missing status ${status}`);
  }
});
