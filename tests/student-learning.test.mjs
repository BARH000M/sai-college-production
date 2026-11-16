import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { canAccessOperations, visibleLearningItems } from "../src/portal/lib/studentLearning.ts";

test("learners see only published items, including an empty result", () => {
  const rows = [{ id: 1, is_published: true }, { id: 2, is_published: false }];
  assert.deepEqual(visibleLearningItems(rows, true), [rows[0]]);
  assert.deepEqual(visibleLearningItems([rows[1]], true), []);
  assert.deepEqual(visibleLearningItems(rows, false), rows);
});

test("student and parent cannot open administrative operations", () => {
  assert.equal(canAccessOperations(["student"]), false);
  assert.equal(canAccessOperations(["parent"]), false);
  assert.equal(canAccessOperations(["admin"]), true);
  assert.equal(canAccessOperations(["student", "super_admin"]), true);
});

test("student course views contain no client lesson-completion writes", async () => {
  const files = [
    new URL("../src/portal/pages/learning/CoursesView.tsx", import.meta.url),
    new URL("../mobile/lib/ui/live_courses.dart", import.meta.url),
  ];
  for (const file of files) {
    const source = await readFile(file, "utf8");
    assert.doesNotMatch(source, /saveLessonProgress|_markComplete|['"]status['"]\s*:\s*['"]completed['"]/);
  }
});

test("student and parent dashboards retain personal attendance and real learning data", async () => {
  const learner = await readFile(new URL("../src/portal/pages/LearnerHome.tsx", import.meta.url), "utf8");
  const parent = await readFile(new URL("../src/portal/pages/home/FamilyHome.tsx", import.meta.url), "utf8");
  assert.match(learner, /PersonalAttendancePanel/);
  assert.match(parent, /PersonalAttendancePanel/);
  assert.match(learner, /loadStudentRecord\(userId\)/);
  assert.match(learner, /loadLearningWorkspace/);
  assert.match(parent, /loadParentChildren\(userId\)/);
});

test("super administrator dashboard retains protected summary, alerts, and error state", async () => {
  const dashboard = await readFile(new URL("../src/portal/pages/home/SuperAdminOverview.tsx", import.meta.url), "utf8");
  const roles = await readFile(new URL("../src/portal/lib/roles.ts", import.meta.url), "utf8");
  assert.match(dashboard, /loadSuperAdminSummary\(\)/);
  assert.match(dashboard, /operational-alerts-title/);
  assert.match(dashboard, /state\.status === "error"/);
  assert.match(dashboard, /useNotificationFeed/);
  assert.match(roles, /manage-roles/);
});
