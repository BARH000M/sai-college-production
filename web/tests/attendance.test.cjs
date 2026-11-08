const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");
const source = fs.readFileSync(path.join(__dirname, "../src/lib/attendance.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__attendanceTestSupabase;");
const code = stripTypeScriptTypes(source, { mode: "strip" });
async function load(suffix, client) {
  globalThis.__attendanceTestSupabase = client;
  return import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#${suffix}`);
}
const item = { id: "c", name: "Class", branch_id: "b", academic_session_id: "s", teacher_id: "teacher" };

test("attendance management is branch and teacher scoped", async () => {
  const api = await load("roles");
  assert.equal(api.canManageAttendance(["super_admin"], "x", [], item), true);
  assert.equal(api.canManageAttendance(["admin"], "x", ["b"], item), true);
  assert.equal(api.canManageAttendance(["admin"], "x", ["other"], item), false);
  assert.equal(api.canManageAttendance(["teacher"], "teacher", ["b"], item), true);
  assert.equal(api.canManageAttendance(["teacher"], "other", ["b"], item), false);
  assert.equal(api.canManageAttendance(["teacher"], "teacher", [], item), false);
  for (const role of ["student", "parent", "accountant", "librarian", "content_editor", "receptionist"]) {
    assert.equal(api.canManageAttendance([role], "teacher", ["b"], item), false);
  }
  assert.equal(api.canCorrectAttendance(["receptionist"], ["b"], "b"), true);
  assert.equal(api.canCorrectAttendance(["receptionist"], [], "b"), false);
  assert.equal(api.canManageAttendance(["teacher", "admin"], "other", ["b"], item), true);
});

test("date validation uses Asia/Aden and rejects future or invalid dates", async () => {
  const api = await load("dates");
  assert.equal(api.attendanceToday(new Date("2026-01-01T22:00:00Z")), "2026-01-02");
  assert.equal(api.validateAttendanceDate("2026-01-02", "2026-01-02"), null);
  assert.ok(api.validateAttendanceDate("2026-01-03", "2026-01-02"));
  assert.ok(api.validateAttendanceDate("2026-02-30", "2026-03-01"));
  assert.equal(api.isAttendanceStatus("constructor"), false);
});

test("session queries apply scope and surface database errors", async () => {
  const calls = [];
  const builder = {
    select(...args) { calls.push(["select", ...args]); return this; },
    eq(...args) { calls.push(["eq", ...args]); return this; },
    order() { return this; }, range(...args) { calls.push(["range", ...args]); return this; },
    returns: async () => ({ data: null, count: null, error: { message: "permission denied" } }),
  };
  const api = await load("query", { from: () => builder });
  await assert.rejects(api.loadAttendanceSessions({ branch: "b", session: "s", classId: "c", date: "2026-01-01", page: 1 }), /permission denied/);
  for (const [field, value] of [["branch_id", "b"], ["academic_session_id", "s"], ["class_id", "c"], ["attendance_date", "2026-01-01"]]) {
    assert.ok(calls.some((call) => call[0] === "eq" && call[1] === field && call[2] === value));
  }
  assert.ok(calls.some((call) => call[0] === "range" && call[1] === 25 && call[2] === 49));
});

test("future creation and duplicate or denied writes never report success", async () => {
  const db = { from: () => ({ insert: async () => ({ error: { message: "duplicate key" } }) }) };
  const api = await load("write", db);
  await assert.rejects(api.createAttendanceSession(item, "9999-12-31"), /المستقبل/);
  const row = { student_id: "student", full_name: "Student", record_id: null, attendance_status: null, note: null };
  await assert.rejects(api.saveAttendance("session", row, "present", ""), /duplicate key/);
  db.from = () => ({ update: () => ({ eq: () => ({ eq: () => ({ select: async () => ({ data: [], error: null }) }) }) }) });
  await assert.rejects(api.saveAttendance("session", { ...row, record_id: "record" }, "present", ""), /لم يُحدّث/);
});

test("attendance implementation exposes no destructive operations", () => {
  for (const file of ["../src/lib/attendance.ts", "../src/pages/Attendance.tsx", "../../supabase/migrations/006_attendance.sql"]) {
    assert.doesNotMatch(fs.readFileSync(path.join(__dirname, file), "utf8"), /\.delete\s*\(|\btruncate\b|\bdelete\s+from\b|\bdrop\b/i);
  }
});
