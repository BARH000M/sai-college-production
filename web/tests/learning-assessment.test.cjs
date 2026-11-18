const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../../src/portal/lib/exercises.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__exerciseTestSupabase;");
const code = stripTypeScriptTypes(source, { mode: "strip" });

async function load(client, suffix = Math.random()) {
  globalThis.__exerciseTestSupabase = client;
  return import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#${suffix}`);
}

function fakeClient({
  rpcResult = { data: null, error: null },
  writeResult = { data: [{ id: "q1" }], error: null },
} = {}) {
  const calls = [];
  return {
    calls,
    rpc: async (...args) => { calls.push(["rpc", ...args]); return rpcResult; },
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
        in(...args) { calls.push(["in", ...args]); return this; },
        order() { return this; },
        limit() { return Promise.resolve({ data: [{ position: 3 }], error: null }); },
        insert(payload) { calls.push(["insert", payload]); this._wrote = writeResult; return this; },
        update(payload) { calls.push(["update", payload]); this._wrote = writeResult; return this; },
        delete() { calls.push(["delete"]); this._wrote = writeResult; return this; },
      };
      return builder;
    },
  };
}

const input = {
  lessonId: "l1", vocabularyId: null, kind: "vocabulary", prompt: "ما معنى 你好؟",
  choices: ["مرحباً", "وداعاً"], correctChoice: 0, isPublished: true,
};

test("question validation rejects unsafe shapes before any write", async () => {
  const client = fakeClient();
  const api = await load(client, "validate");
  await assert.rejects(api.createExerciseQuestion({ ...input, prompt: "أ" }), /نص السؤال/);
  await assert.rejects(api.createExerciseQuestion({ ...input, choices: ["واحد"] }), /خيارين وستة/);
  await assert.rejects(api.createExerciseQuestion({ ...input, choices: ["أ", "أ"] }), /المكررة/);
  await assert.rejects(api.createExerciseQuestion({ ...input, correctChoice: 2 }), /الإجابة الصحيحة/);
  assert.equal(client.calls.filter((call) => call[0] === "insert").length, 0);
});

test("question creation writes the answer key server-side and appends position", async () => {
  const client = fakeClient();
  const api = await load(client, "create");
  assert.equal(await api.createExerciseQuestion({ ...input, vocabularyId: "w1" }), "q1");
  const insert = client.calls.find((call) => call[0] === "insert");
  assert.equal(insert[1].lesson_id, "l1");
  assert.equal(insert[1].correct_choice, 0);
  assert.equal(insert[1].vocabulary_id, "w1");
  assert.equal(insert[1].position, 4);
  assert.equal(client.calls.some((call) => call[0] === "select" && String(call[1]).includes("correct_choice")), false);

  const denied = fakeClient({ writeResult: { data: null, error: { message: "permission denied" } } });
  const api2 = await load(denied, "create-denied");
  await assert.rejects(api2.createExerciseQuestion(input), /permission denied/);
});

test("student question loads never request the answer key column", async () => {
  const client = fakeClient({ writeResult: { data: [], error: null } });
  const api = await load(client, "read");
  await api.loadExerciseQuestions("l1");
  const select = client.calls.find((call) => call[0] === "select");
  assert.ok(!String(select[1]).includes("correct_choice"));
  assert.deepEqual(client.calls.find((call) => call[0] === "in"),
    ["in", "kind", ["vocabulary", "listening"]]);
  await assert.rejects(
    load(fakeClient(), "bad-shape").then((m) => m.submitExercise("l1", [])),
    /سؤال واحد/,
  );
});

test("submission delegates grading to the server and validates the outcome", async () => {
  const rpcResult = {
    data: { total: 2, correct: 1, score: 50, passed: false, results: [{ question: "q1", correct: true }] },
    error: null,
  };
  const client = fakeClient({ rpcResult });
  const api = await load(client, "submit");
  const outcome = await api.submitExercise("l1", [{ question: "q1", choice: 1 }]);
  assert.equal(outcome.score, 50);
  assert.equal(outcome.passed, false);
  const rpc = client.calls.find((call) => call[0] === "rpc");
  assert.equal(rpc[1], "sai_learning_submit_exercise");
  assert.deepEqual(rpc[2].p_answers, [{ question: "q1", choice: 1 }]);

  const broken = fakeClient({ rpcResult: { data: { total: 2 }, error: null } });
  const api2 = await load(broken, "submit-broken");
  await assert.rejects(api2.submitExercise("l1", [{ question: "q1", choice: 0 }]), /استجابة التصحيح غير صالحة/);

  const denied = fakeClient({ rpcResult: { data: null, error: { message: "Not enrolled" } } });
  const api3 = await load(denied, "submit-denied");
  await assert.rejects(api3.submitExercise("l1", [{ question: "q1", choice: 0 }]), /Not enrolled/);
});

test("assessed completion is labelled distinctly from self-reported practice", async () => {
  const learning = fs.readFileSync(path.join(__dirname, "../../src/portal/lib/learning.ts"), "utf8");
  assert.match(learning, /completion_basis === "assessed"\) return "مكتمل بتقييم مُصحَّح"/);
  const migration = fs.readFileSync(
    path.join(__dirname, "../../supabase/migrations/20261116013950_learning_scored_exercises.sql"), "utf8");
  assert.match(migration, /in \('self_reported', 'assessed'\)/);
  assert.match(migration, /grant select \(id, lesson_id, vocabulary_id, kind, prompt, choices, position, is_published, created_at\)/);
  assert.doesNotMatch(migration, /grant select .*correct_choice/);
});
