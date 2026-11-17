const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../../src/portal/lib/learningAccounts.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__learningAccountsTestSupabase;")
  .replace('"./functionErrors"', JSON.stringify(`data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(fs.readFileSync(path.join(__dirname, "../../src/portal/lib/functionErrors.ts"), "utf8"), { mode: "strip" })).toString("base64")}`));
const code = stripTypeScriptTypes(source, { mode: "strip" });

async function load(suffix, supabase) {
  globalThis.__learningAccountsTestSupabase = supabase;
  return import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#${suffix}`);
}

test("staff account provisioning sends an invitation without a password", async () => {
  const calls = [];
  const account = {
    userId: "user-1",
    email: "student@example.test",
    role: "student",
    fullName: "Student",
    studentName: "Student",
    inviteSent: true,
    roleActivationPending: true,
  };
  const api = await load("invite", {
    functions: {
      invoke: async (...args) => {
        calls.push(args);
        return { data: { ok: true, account }, error: null };
      },
    },
  });

  assert.deepEqual(await api.provisionLearningAccount({
    studentId: "student-1",
    kind: "student",
    email: "student@example.test",
  }), account);
  assert.deepEqual(calls, [["provision-learning-account", {
    body: {
      action: "create",
      studentId: "student-1",
      kind: "student",
      email: "student@example.test",
    },
  }]]);
  assert.equal("password" in calls[0][1].body, false);
});

test("account provisioning rejects an unconfirmed invitation response", async () => {
  const api = await load("unconfirmed", {
    functions: {
      invoke: async () => ({
        data: {
          ok: true,
          account: {
            userId: "user-1",
            email: "student@example.test",
            role: "student",
            fullName: "Student",
            studentName: "Student",
            inviteSent: false,
          },
        },
        error: null,
      }),
    },
  });

  await assert.rejects(api.provisionLearningAccount({
    studentId: "student-1",
    kind: "student",
    email: "student@example.test",
  }), /لم تؤكد الخدمة إرسال دعوة الحساب/);
});

test("teacher invitation omits passwords and requires pending access acknowledgement", async () => {
  const calls = [];
  const account = { userId: 'teacher', fullName: 'Teacher', email: 'teacher@example.test', className: 'Proposed', inviteSent: true, roleActivationPending: true };
  const api = await load('teacher-invite', { functions: { invoke: async (...args) => { calls.push(args); return { data: { ok: true, account }, error: null }; } } });
  assert.deepEqual(await api.provisionTeacherAccount({ fullName: 'Teacher', email: 'teacher@example.test', classId: 'class' }), account);
  assert.equal('password' in calls[0][1].body, false);
  const stale = await load('teacher-old-response', { functions: { invoke: async () => ({ data: { ok: true, account: { ...account, roleActivationPending: false } }, error: null }) } });
  await assert.rejects(stale.provisionTeacherAccount({ fullName: 'Teacher', email: 'teacher@example.test', classId: 'class' }));
});
