const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../../src/portal/lib/assessments.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__assessmentTestSupabase;");
const code = stripTypeScriptTypes(source, { mode: "strip" });

async function load(client, suffix = Math.random()) {
  globalThis.__assessmentTestSupabase = client;
  return import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#${suffix}`);
}

function fakeClient({ rpcResult = { data: null, error: null }, writeResult = { data: [{ id: "created" }], error: null } } = {}) {
  const calls = [];
  return {
    calls,
    rpc: async (...args) => { calls.push(["rpc", ...args]); return rpcResult; },
    from(table) {
      calls.push(["from", table]);
      const builder = {
        wrote: null,
        select(...args) {
          if (this.wrote) return Promise.resolve(this.wrote);
          calls.push(["select", ...args]);
          return this;
        },
        eq(...args) { calls.push(["eq", ...args]); return this; },
        order(...args) { calls.push(["order", ...args]); return this; },
        limit(...args) { calls.push(["limit", ...args]); return Promise.resolve({ data: [], error: null }); },
        insert(payload) { calls.push(["insert", payload]); this.wrote = writeResult; return this; },
        update(payload) { calls.push(["update", payload]); this.wrote = writeResult; return this; },
        delete() { calls.push(["delete"]); this.wrote = writeResult; return this; },
      };
      return builder;
    },
  };
}

const question = {
  assessmentId: "assessment-1",
  lessonId: "lesson-1",
  kind: "matching",
  prompt: "طابق الكلمات",
  points: 2,
  choices: ["صباح", "مساء", "早", "晚"],
  correctChoice: null,
  answerKey: { صباح: "早", مساء: "晚" },
};

test("assessment question validation prevents malformed pair maps from reaching writes", async () => {
  const client = fakeClient();
  const api = await load(client, "bad-pairs");
  await assert.rejects(api.createAssessmentQuestion({
    ...question,
    choices: ["صباح", "مساء", "早"],
  }), /العدد نفسه/);
  assert.equal(client.calls.filter((call) => call[0] === "insert").length, 0);
});

test("authoring persists a validated matching answer key with lesson and assessment association", async () => {
  const client = fakeClient();
  const api = await load(client, "matching");
  await api.createAssessmentQuestion(question);
  const inserted = client.calls.find((call) => call[0] === "insert")[1];
  assert.equal(inserted.assessment_id, "assessment-1");
  assert.equal(inserted.lesson_id, "lesson-1");
  assert.deepEqual(inserted.choices, question.choices);
  assert.deepEqual(inserted.answer_key, question.answerKey);
  assert.equal(inserted.is_published, false);
});

test("student start parses only safe question fields and save delegates to server RPC", async () => {
  const client = fakeClient({
    rpcResult: {
      data: {
        attempt_id: "attempt-1",
        attempt_number: 1,
        due_at: null,
        saved_answers: { "q-1": "مرحباً" },
        questions: [{
          id: "q-1", kind: "fill_blank", prompt: "أكمل",
          choices: [], points: 1, position: 1,
        }],
      },
      error: null,
    },
  });
  const api = await load(client, "student");
  const attempt = await api.startAssessment("assessment-1");
  assert.equal(attempt.questions[0].kind, "fill_blank");
  assert.equal(attempt.saved_answers["q-1"], "مرحباً");
  assert.equal("answer_key" in attempt.questions[0], false);
  await api.saveAssessmentAnswer(attempt.attempt_id, "q-1", "مرحباً");
  const rpc = client.calls.filter((call) => call[0] === "rpc");
  assert.equal(rpc[0][1], "sai_learning_assessment_start");
  assert.equal(rpc[1][1], "sai_learning_assessment_save");
  assert.deepEqual(rpc[1][2], { p_attempt: "attempt-1", p_question: "q-1", p_answer: "مرحباً" });
});

test("written grading validates the RPC response path and surfaces permission failures", async () => {
  const allowed = fakeClient({ rpcResult: { data: null, error: null } });
  const api = await load(allowed, "grade");
  await api.gradeAssessmentAnswer("answer-1", 1.5, "  جيد  ");
  assert.deepEqual(allowed.calls[0], ["rpc", "sai_learning_assessment_grade", {
    p_answer: "answer-1", p_points: 1.5, p_feedback: "جيد",
  }]);

  const denied = fakeClient({ rpcResult: { data: null, error: { message: "not authorized" } } });
  const deniedApi = await load(denied, "grade-denied");
  await assert.rejects(deniedApi.gradeAssessmentAnswer("answer-1", 1, ""), /not authorized/);
});

test("assessment scheduling and grading settings are validated before database writes", async () => {
  const client = fakeClient();
  const api = await load(client, "schedule-settings");
  await assert.rejects(api.createAssessment({
    courseId: "course-1",
    lessonId: "lesson-1",
    title: "Scheduled quiz",
    instructions: "",
    startsAt: "2030-01-02T10:00:00Z",
    dueAt: "2030-01-02T09:00:00Z",
    timeLimitMinutes: 30,
    attemptLimit: 2,
    passingScore: 70,
    randomizeQuestions: true,
  }), /موعد الإغلاق بعد موعد البدء/);
  assert.equal(client.calls.length, 0);

  await api.createAssessment({
    courseId: "course-1",
    lessonId: "lesson-1",
    title: "Scheduled quiz",
    instructions: "",
    startsAt: "2030-01-02T08:00:00Z",
    dueAt: "2030-01-02T10:00:00Z",
    timeLimitMinutes: 30,
    attemptLimit: 2,
    passingScore: 75.5,
    randomizeQuestions: true,
  });
  const payload = client.calls.find((call) => call[0] === "insert")[1];
  assert.equal(payload.starts_at, "2030-01-02T08:00:00.000Z");
  assert.equal(payload.time_limit_minutes, 30);
  assert.equal(payload.passing_score, 75.5);
  assert.equal(payload.randomize_questions, true);
});

test("assessment duplication and individual assignment use authorized server RPCs", async () => {
  const duplicateClient = fakeClient({
    rpcResult: { data: "copy-id", error: null },
  });
  const duplicateApi = await load(duplicateClient, "duplicate-assessment");
  assert.equal(await duplicateApi.duplicateAssessment("assessment-1"), "copy-id");
  assert.deepEqual(duplicateClient.calls[0], ["rpc", "sai_learning_assessment_duplicate", {
    p_assessment: "assessment-1",
    p_title: null,
  }]);

  const assignmentClient = fakeClient({ rpcResult: { data: 2, error: null } });
  const assignmentApi = await load(assignmentClient, "assign-assessment");
  assert.equal(await assignmentApi.assignAssessmentStudents("assessment-1", ["student-1", "student-2"]), 2);
  assert.deepEqual(assignmentClient.calls[0], ["rpc", "sai_learning_assessment_assign", {
    p_assessment: "assessment-1",
    p_student_ids: ["student-1", "student-2"],
  }]);
  await assert.rejects(assignmentApi.assignAssessmentStudents("assessment-1", ["student-1", "student-1"]), /تكرار/);
  assert.equal(assignmentClient.calls.length, 1);
});

test("timed-out attempts are parsed as submitted without questions or answer keys", async () => {
  const client = fakeClient({
    rpcResult: {
      data: {
        attempt_id: "attempt-1",
        attempt_number: 1,
        status: "submitted",
        timed_out: true,
        due_at: null,
        expires_at: "2030-01-02T10:30:00Z",
        passing_score: 70,
        questions: [],
        saved_answers: {},
      },
      error: null,
    },
  });
  const api = await load(client, "timed-out-attempt");
  const attempt = await api.startAssessment("assessment-1");
  assert.equal(attempt.status, "submitted");
  assert.equal(attempt.timed_out, true);
  assert.deepEqual(attempt.questions, []);
});
