const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../../src/portal/lib/learning.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__learningTestSupabase;")
  .replace('import { visibleLearningItems } from "./studentLearning";', "const visibleLearningItems = (rows) => rows;");
const code = stripTypeScriptTypes(source, { mode: "strip" });

async function load(client, suffix = Math.random()) {
  globalThis.__learningTestSupabase = client;
  return import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#${suffix}`);
}

function fakeClient({
  progressRow = null,
  maxPosition = 2,
  insertResult = { data: [{ id: "lesson-1" }], error: null },
  upsertResult = { data: [{ lesson_id: "l" }], error: null },
  updateResult = { data: [{ id: "lesson-1" }], error: null },
} = {}) {
  const calls = [];
  return {
    calls,
    from(table) {
      calls.push(["from", table]);
      const builder = {
        _wrote: null,
        select(...args) {
          if (this._wrote) return Promise.resolve(this._wrote);
          calls.push(["select", ...args]);
          return this;
        },
        eq() { return this; },
        order() { return this; },
        limit() { return Promise.resolve({ data: [{ position: maxPosition }], error: null }); },
        maybeSingle() { return Promise.resolve({ data: progressRow, error: null }); },
        insert(payload) { calls.push(["insert", payload]); this._wrote = insertResult; return this; },
        upsert(payload, options) { calls.push(["upsert", payload, options]); this._wrote = upsertResult; return this; },
        update(payload) { calls.push(["update", payload]); this._wrote = updateResult; return this; },
      };
      return builder;
    },
  };
}

const lesson = { content_kind: "none", content_body: null, content_path: null, content_url: null };
const input = { courseId: "c1", title: "درس التحية", summary: "", kind: "lesson", durationMinutes: 45, isPublished: true };

test("exercise plan derives only from real content and vocabulary", async () => {
  const api = await load({}, "plan");
  assert.deepEqual(api.lessonExercisePlan(lesson, 0), []);
  const plan = api.lessonExercisePlan({ ...lesson, content_kind: "audio", content_path: "a/b.mp3", content_body: "x".repeat(25) }, 3);
  assert.deepEqual(plan.map((item) => item.id), ["reading", "listening", "vocabulary"]);
  assert.equal(plan[2].total, 3);
  assert.equal(api.canCompleteLesson([], {}), false);
  assert.equal(api.canCompleteLesson(plan, { reading: 1, listening: 1, vocabulary: 2 }), false);
  assert.equal(api.canCompleteLesson(plan, { reading: 1, listening: 1, vocabulary: 3 }), true);
});

test("completion labels distinguish exercise-verified from legacy rows", async () => {
  const api = await load({}, "labels");
  assert.equal(api.lessonProgressLabel(null), "لم يبدأ");
  assert.equal(api.lessonProgressLabel({ status: "in_progress", completion_basis: null }), "قيد الدراسة");
  assert.equal(api.lessonProgressLabel({ status: "completed", completion_basis: null }), "حالة إكمال سابقة غير متحققة");
  assert.equal(api.lessonProgressLabel({ status: "completed", completion_basis: "self_reported" }), "أكمل التمارين ذاتياً (غير معتمد)");
});

test("lesson creation validates input and appends to course order", async () => {
  const api = await load(fakeClient(), "create");
  await assert.rejects(api.createLesson({ ...input, title: "اب" }), /عنوان الدرس/);
  await assert.rejects(api.createLesson({ ...input, kind: "quiz" }), /نوع الدرس/);
  await assert.rejects(api.createLesson({ ...input, durationMinutes: 0 }), /مدة الدرس/);

  const client = fakeClient({ maxPosition: 4 });
  const api2 = await load(client, "create-ok");
  assert.equal(await api2.createLesson(input), "lesson-1");
  const insert = client.calls.find((call) => call[0] === "insert");
  assert.equal(insert[1].course_id, "c1");
  assert.equal(insert[1].position, 5);
  assert.equal(insert[1].is_published, true);

  const failing = fakeClient({ insertResult: { data: null, error: { message: "permission denied" } } });
  const api3 = await load(failing, "create-denied");
  await assert.rejects(api3.createLesson(input), /permission denied/);
});

test("lesson update is scoped to id and course and never reports silent success", async () => {
  const client = fakeClient({ updateResult: { data: [], error: null } });
  const api = await load(client, "update");
  await assert.rejects(api.updateLesson("l1", input, 2), /لم يُحفظ التعديل/);
  const ok = fakeClient();
  const api2 = await load(ok, "update-ok");
  await api2.updateLesson("l1", input, 2);
  const update = ok.calls.find((call) => call[0] === "update");
  assert.equal(update[1].title, "درس التحية");
  assert.equal(update[1].position, 2);
});

test("lesson start never downgrades an existing completion", async () => {
  const completed = fakeClient({ progressRow: { status: "completed" } });
  const api = await load(completed, "start-completed");
  await api.recordLessonStart("l1", "s1");
  assert.equal(completed.calls.some((call) => call[0] === "upsert"), false);

  const inProgress = fakeClient({ progressRow: { status: "in_progress" } });
  const api2 = await load(inProgress, "start-progress");
  await api2.recordLessonStart("l1", "s1");
  assert.equal(inProgress.calls.some((call) => call[0] === "upsert"), false);

  const fresh = fakeClient();
  const api3 = await load(fresh, "start-new");
  await api3.recordLessonStart("l1", "s1");
  const upsert = fresh.calls.find((call) => call[0] === "upsert");
  assert.equal(upsert[1].status, "in_progress");
  assert.equal(upsert[2].onConflict, "lesson_id,student_id");
});

test("lesson completion is recorded as self-reported practice, not verified mastery", async () => {
  const client = fakeClient();
  const api = await load(client, "finish");
  await api.recordLessonCompletion("l1", "s1");
  const upsert = client.calls.find((call) => call[0] === "upsert");
  assert.equal(upsert[1].status, "completed");
  assert.equal(upsert[1].completion_basis, "self_reported");

  const denied = fakeClient({ upsertResult: { data: [], error: null } });
  const api2 = await load(denied, "finish-denied");
  await assert.rejects(api2.recordLessonCompletion("l1", "s1"), /لم يُسجَّل الإكمال/);
});
