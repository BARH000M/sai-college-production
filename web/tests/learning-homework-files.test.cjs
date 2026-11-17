const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../../src/portal/lib/learning.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__learningTestSupabase;")
  .replace('import { visibleLearningItems } from "./studentLearning";', "const visibleLearningItems = (rows) => rows;");
const code = stripTypeScriptTypes(source, { mode: "strip" });

async function load(client) {
  globalThis.__learningTestSupabase = client;
  return import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#${Math.random()}`);
}

function fakeClient() {
  const calls = [];
  return {
    calls,
    storage: {
      from(bucket) {
        return {
          upload: async (filePath, file, options) => {
            calls.push(["upload", bucket, filePath, file.name, options]);
            return { data: { path: filePath }, error: null };
          },
          createSignedUrl: async (filePath, expiresIn) => {
            calls.push(["signedUrl", bucket, filePath, expiresIn]);
            return { data: { signedUrl: "https://signed.test/file" }, error: null };
          },
        };
      },
    },
    from(table) {
      const builder = {
        result: { data: [{ id: "saved" }], error: null },
        upsert(payload, options) {
          calls.push(["upsert", table, payload, options]);
          return this;
        },
        update(payload) {
          calls.push(["update", table, payload]);
          return this;
        },
        eq(...args) {
          calls.push(["eq", ...args]);
          return this;
        },
        select(...args) {
          calls.push(["select", ...args]);
          return Promise.resolve(this.result);
        },
      };
      return builder;
    },
  };
}

test("students can submit a supported private file without text", async () => {
  const client = fakeClient();
  const api = await load(client);
  const file = { name: "homework.pdf", size: 20, type: "application/pdf" };
  await api.submitHomework("homework-1", "student-1", "", file);

  const upload = client.calls.find((call) => call[0] === "upload");
  assert.equal(upload[1], "homework-files");
  assert.match(upload[2], /^homework-1\/submissions\/student-1\//);
  const write = client.calls.find((call) => call[0] === "upsert");
  assert.equal(write[2].content, null);
  assert.equal(write[2].submission_file_name, file.name);
  assert.equal(write[2].status, "submitted");
  assert.equal(write[3].onConflict, "homework_id,student_id");
});

test("text submission still requires the minimum answer and signed links stay private", async () => {
  const client = fakeClient();
  const api = await load(client);
  await assert.rejects(api.submitHomework("homework-1", "student-1", "short"), /عشرة أحرف/);
  assert.equal(client.calls.some((call) => call[0] === "upsert"), false);

  const url = await api.homeworkFileUrl("homework-1/instructions/brief.pdf");
  assert.equal(url, "https://signed.test/file");
  assert.deepEqual(client.calls.at(-1), [
    "signedUrl", "homework-files", "homework-1/instructions/brief.pdf", 300,
  ]);
});

test("teacher attachment upload links only the uploaded object to its homework", async () => {
  const client = fakeClient();
  const api = await load(client);
  await api.uploadHomeworkAttachment("homework-2", {
    name: "brief.docx", size: 40, type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  });
  const update = client.calls.find((call) => call[0] === "update");
  assert.equal(update[1], "learning_homework");
  assert.equal(update[2].attachment_file_name, "brief.docx");
  assert.match(update[2].attachment_path, /^homework-2\/instructions\//);
});
