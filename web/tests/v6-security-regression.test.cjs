const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const root = path.join(__dirname, "..", "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");

const groupC = read("supabase/migrations/20261121130000_v6_group_c_content_approvals.sql");
const groupE = read("supabase/migrations/20261121131000_v6_group_e_reception.sql");
const quizFix = read("supabase/migrations/20261121132000_v6_quiz_delivery_and_media_usage.sql");

/* ------------------------------------------------------------------ *
 * Group C — Content Review & Approvals
 * ------------------------------------------------------------------ */

test("Group C enables RLS on every editorial table", () => {
  for (const table of ["sai_content_items", "sai_content_comments", "sai_content_history"]) {
    assert.match(groupC, new RegExp(`alter table public\\.${table} enable row level security`), `${table} must have RLS`);
  }
});

test("Group C writes are gated to authenticated editorial roles", () => {
  assert.match(groupC, /create policy sai_content_items_insert on public\.sai_content_items\s+for insert to authenticated/);
  assert.match(groupC, /create policy sai_content_items_select on public\.sai_content_items\s+for select to authenticated/);
  // Students must only read published rows inside their branch.
  assert.match(groupC, /status = 'published'[\s\S]*?sai_security_can_read_branch\(branch_id\)/);
  // The author identity is enforced on insert, never trusted from the client.
  assert.match(groupC, /author_id = auth\.uid\(\)/);
});

test("Group C transition function enforces separation of duties and the state machine", () => {
  assert.match(groupC, /create or replace function public\.sai_content_transition\(/);
  assert.match(groupC, /security definer/);
  assert.match(groupC, /Institutional separation of duties prevents self-approval/);
  assert.match(groupC, /when 'draft'\s+then p_next_status = 'submitted'/);
  assert.match(groupC, /when 'submitted'\s+then p_next_status in \('changes_requested','approved','rejected'\)/);
  // Every transition writes history and audit rows.
  assert.match(groupC, /insert into public\.sai_content_history/);
  assert.match(groupC, /perform public\.sai_write_audit\(/);
});

/* ------------------------------------------------------------------ *
 * Group E — Reception & Front Office
 * ------------------------------------------------------------------ */

const receptionTables = [
  "sai_enquiry_followups",
  "sai_visitors",
  "sai_appointments",
  "sai_complaints",
  "sai_phone_logs",
  "sai_correspondence",
];

test("Group E enables RLS on every reception register", () => {
  for (const table of receptionTables) {
    assert.match(groupE, new RegExp(`alter table public\\.${table} enable row level security`), `${table} must have RLS`);
  }
});

test("Group E registers are branch-scoped and never expose a delete policy", () => {
  assert.match(groupE, /sai_visitors_select[\s\S]*?sai_security_can_read_branch\(branch_id\)/);
  assert.match(groupE, /sai_appointments_select[\s\S]*?sai_security_can_read_branch\(branch_id\)/);
  assert.match(groupE, /sai_complaints_select[\s\S]*?sai_security_can_read_branch\(branch_id\)/);
  assert.doesNotMatch(groupE, /for delete/i, "reception history must be retained; no delete policy is allowed");
});

test("Group E reuses the admissions enquiry contract instead of duplicating it", () => {
  assert.match(groupE, /references public\.admissions_enquiries\(id\)/);
  assert.doesNotMatch(groupE, /create table if not exists public\.admissions_enquiries/, "the enquiry table must not be recreated");
  // Shared numbers are a warning, not a silent rejection: it is indexed for review.
  assert.match(groupE, /create index if not exists sai_visitors_phone_idx on public\.sai_visitors \(phone_normalized\)/);
});

/* ------------------------------------------------------------------ *
 * Quiz safe projection (the highest-severity security fix)
 * ------------------------------------------------------------------ */

test("the student-safe question view never exposes the answer key", () => {
  const view = quizFix.slice(
    quizFix.indexOf("create or replace view public.sai_quiz_public_questions"),
    quizFix.indexOf("comment on view"),
  );
  assert.ok(view.length > 0, "the safe view must be defined");
  assert.doesNotMatch(view, /correct_choice/, "correct_choice must never be projected");
  assert.doesNotMatch(view, /answer_key/, "answer_key must never be projected");
  assert.match(view, /sai_quiz_can_access_assessment\(q\.assessment_id\)/);
});

test("the eligibility helper is a security-definer function that gates access", () => {
  assert.match(quizFix, /create or replace function public\.sai_quiz_can_access_assessment/);
  assert.match(
    quizFix.slice(quizFix.indexOf("sai_quiz_can_access_assessment(p_assessment_id"), quizFix.indexOf("create or replace view")),
    /security definer/,
  );
});

/* ------------------------------------------------------------------ *
 * Lab integration — six labs read real curriculum and media
 * ------------------------------------------------------------------ */

test("the lab repository loads real courses, lessons, vocabulary and media", () => {
  const repo = read("src/portal/lib/labRepository.ts");
  assert.match(repo, /from\("learning_courses"\)/);
  assert.match(repo, /from\("learning_lessons"\)/);
  assert.match(repo, /from\("learning_vocabulary"\)/);
  assert.match(repo, /from\("sai_media_assets"\)/);
  assert.match(repo, /export async function loadLabWorkspace/);
  assert.match(repo, /export function buildLabDatasets/);
});

test("every lab consumes the shared real-data provider instead of the mock module", () => {
  const labs = ["ListeningLab", "SpeakingLab", "TonesLab", "HandwritingLab", "ReadingLab"];
  for (const lab of labs) {
    const source = read(`src/portal/pages/labs/${lab}.tsx`);
    assert.match(source, /useLabDatasets\(\)/, `${lab} must load the real datasets`);
    assert.doesNotMatch(source, /from "@\/mocks\/learningLabs"/, `${lab} must no longer import the mock module directly`);
  }
  const entry = read("src/portal/pages/ModuleEntry.tsx");
  assert.match(entry, /LabDataProvider/);
  for (const lab of [...labs, "ReviewLab"]) {
    assert.match(entry, new RegExp(`<LabDataProvider><${lab} /></LabDataProvider>`), `${lab} must be wrapped by the provider`);
  }
});

/* ------------------------------------------------------------------ *
 * Pure builders behave deterministically
 * ------------------------------------------------------------------ */

const labSource = read("src/portal/lib/labRepository.ts")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__labSupabase;");
const labCode = stripTypeScriptTypes(labSource, { mode: "strip" });

async function loadLab(suffix = Math.random()) {
  return import(`data:text/javascript;base64,${Buffer.from(labCode).toString("base64")}#${suffix}`);
}

const fallback = {
  listeningLessons: [], toneReferences: [], tonePractice: [],
  speakingDrills: [], handwritingChars: [], readingPassages: [], reviewCards: [], labSummaryStats: [],
};

function word(id, hanzi, pinyin, meaning, example) {
  return {
    id, course_id: "c1", lesson_id: "l1", hanzi, pinyin,
    meaning_ar: meaning, meaning_en: null, example_zh: example, example_ar: null, hsk_level: 1,
  };
}

test("toneOf maps toned vowels to their tone number", async () => {
  const lab = await loadLab("tone");
  assert.equal(lab.toneOf("mā"), 1);
  assert.equal(lab.toneOf("má"), 2);
  assert.equal(lab.toneOf("mǎ"), 3);
  assert.equal(lab.toneOf("mà"), 4);
  assert.equal(lab.toneOf("ma"), 5);
});

test("optionsFor always includes the correct answer among four unique choices", async () => {
  const lab = await loadLab("options");
  const options = lab.optionsFor("mǎ", ["mǎ", "mā", "má", "mà"], 2);
  assert.equal(options.length, 4);
  assert.ok(options.includes("mǎ"), "the correct answer must be present");
  assert.equal(new Set(options).size, 4, "choices must be unique");
});

test("buildLabDatasets derives practice from real vocabulary and falls back when empty", async () => {
  const lab = await loadLab("datasets");
  const workspace = {
    courses: [{ id: "c1", title: "اللغة الصينية", level: "المستوى الأول" }],
    lessons: [{ id: "l1", course_id: "c1", title: "التعريف بالنفس", summary: "تحية", kind: "lesson", duration_minutes: 45, content_body: null }],
    vocabulary: [
      word("w1", "你", "nǐ", "أنت", "你好！"),
      word("w2", "好", "hǎo", "جيد", "我很好。"),
      word("w3", "学", "xué", "يتعلم", "我学中文。"),
      word("w4", "书", "shū", "كتاب", "هذا كتابي。"),
      word("w5", "马", "mǎ", "حصان", "那匹马很快。"),
    ],
    audio: [],
    learnerId: null,
  };
  const data = lab.buildLabDatasets(workspace, fallback);
  assert.equal(data.tonePractice.length, 5);
  for (const item of data.tonePractice) assert.ok(item.options.includes(item.pinyin), "each tone item keeps its answer");
  assert.equal(data.speakingDrills.length, 5);
  assert.equal(data.handwritingChars.length, 5);
  assert.ok(data.readingPassages.length >= 1, "reading passages derive from lesson examples");
  assert.ok(data.listeningLessons.length >= 1, "listening lessons derive from lesson examples");
  assert.equal(data.labSummaryStats.find((row) => row.id === "ls1").value, "5");

  const empty = lab.buildLabDatasets(null, { ...fallback, tonePractice: [{ id: "x" }] });
  assert.deepEqual(empty.tonePractice, [{ id: "x" }], "a null workspace falls back to curated content");
});