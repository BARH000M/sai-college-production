import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { navigation } from "../src/portal/lib/navigation.ts";

test("teacher navigation excludes finance and role administration", () => {
  assert.equal(navigation.find((item) => item.id === "courses").roles.includes("teacher"), true);
  assert.equal(navigation.find((item) => item.id === "finance").roles.includes("teacher"), false);
  assert.equal(navigation.find((item) => item.id === "roles").roles.includes("teacher"), false);
});

test("teacher learning queries select assigned classes", async () => {
  const source = await readFile(new URL("../src/portal/lib/learning.ts", import.meta.url), "utf8");
  assert.match(source, /eq\("teacher_id", teacherUserId\)/);
  assert.match(source, /in\("class_id", ids\)/);
  assert.match(source, /classByHomework\.get\(row\.homework_id\) === classByStudent\.get\(row\.student_id\)/);
});

test("teacher dashboard loads assigned sections and scopes attendance to those sections", async () => {
  const dashboard = await readFile(new URL("../src/portal/pages/home/TeacherHome.tsx", import.meta.url), "utf8");
  const home = await readFile(new URL("../src/portal/lib/home.ts", import.meta.url), "utf8");
  assert.match(dashboard, /loadTeacherHome\(userId\)/);
  assert.match(dashboard, /loadLearningWorkspace\(false,\s*undefined,\s*userId\)/);
  assert.match(dashboard, /\.in\("class_id", ids\)/);
  const teacherQuery = home.slice(home.indexOf("export async function loadTeacherHome"));
  assert.match(teacherQuery, /\.eq\("teacher_id", userId\)/);
});
