const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const source = fs.readFileSync(path.join(__dirname, "../../src/portal/lib/admissions.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__admissionsTestSupabase;");
const code = stripTypeScriptTypes(source, { mode: "strip" });
async function load(suffix, client) {
  globalThis.__admissionsTestSupabase = client;
  return import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#${suffix}`);
}
function client(response) {
  const calls = [];
  const builder = {
    select(...args) { calls.push(["select", ...args]); return this; },
    eq(...args) { calls.push(["eq", ...args]); return this; },
    is(...args) { calls.push(["is", ...args]); return this; },
    or(...args) { calls.push(["or", ...args]); return this; },
    order(...args) { calls.push(["order", ...args]); return this; },
    range(...args) { calls.push(["range", ...args]); return this; },
    returns() { return Promise.resolve(response); },
    update(...args) { calls.push(["update", ...args]); return this; },
    insert(...args) { calls.push(["insert", ...args]); return Promise.resolve(response); },
    then(resolve, reject) { return Promise.resolve(response).then(resolve, reject); },
  };
  return {
    calls,
    from(table) { calls.push(["from", table]); return builder; },
    rpc(name, args) {
      calls.push(["rpc", name, args]);
      return Promise.resolve(response);
    },
  };
}
const filters = { branch: "", session: "", status: "", assignee: "", search: "", page: 0 };

test("admissions role visibility and management permissions", async () => {
  const api = await load("roles");
  for (const role of ["super_admin", "admin", "receptionist"]) assert.equal(api.canManageAdmissions([role]), true);
  for (const role of ["teacher", "student", "parent", "accountant", "librarian", "content_editor"]) assert.equal(api.canManageAdmissions([role]), false);
  assert.equal(api.canManageAdmissions(["teacher", "admin"]), true);
});

test("status validation and immutable edit fields", async () => {
  const api = await load("draft");
  const draft = api.admissionDraft(null, "branch", "session");
  draft.applicant_full_name = "Applicant";
  for (const status of Object.keys(api.admissionStatuses)) {
    draft.status = status;
    assert.equal(api.validateAdmission(draft), null);
  }
  draft.status = "unknown";
  assert.ok(api.validateAdmission(draft));
  draft.status = "new";
  const edit = api.admissionPayload(draft, true);
  for (const field of ["id", "branch_id", "application_no", "created_by", "created_at", "updated_at", "closed_at"]) {
    assert.equal(field in edit, false);
  }
  assert.equal("status" in edit, false);
  assert.equal("status" in api.admissionPayload(draft, false), false);
});

test("status changes and enrollment use their guarded RPCs", async () => {
  const db = client({ data: null, error: null });
  const api = await load("status-rpcs", db);
  await api.setAdmissionStatus("enquiry", "accepted");
  assert.deepEqual(db.calls.at(-1), ["rpc", "sai_admissions_set_status", {
    p_enquiry_id: "enquiry",
    p_status: "accepted",
  }]);
  await assert.rejects(api.setAdmissionStatus("enquiry", "enrolled"), /التسجيل الآمن/);

  db.rpc = (name, args) => {
    db.calls.push(["rpc", name, args]);
    return Promise.resolve({
      data: { student_id: "student", admission_no: "SAI-APP-1042" },
      error: null,
    });
  };
  assert.deepEqual(await api.enrollAdmission("enquiry"), {
    student_id: "student",
    admission_no: "SAI-APP-1042",
  });
  assert.equal(db.calls.at(-1)[1], "sai_admissions_enroll");
});

test("enquiries require both branch and session", async () => {
  const api = await load("required");
  const draft = api.admissionDraft(null, "branch", "session");
  draft.applicant_full_name = "Applicant";
  assert.equal(api.validateAdmission(draft), null);
  assert.ok(api.validateAdmission({ ...draft, branch_id: "" }));
  assert.ok(api.validateAdmission({ ...draft, academic_session_id: "" }));
});

test("session directory is branch-scoped, paginated and surfaces errors", async () => {
  const calls = [];
  const db = { rpc(name, args, options) {
    calls.push([name, args, options]);
    return { range: async (start, end) => {
      calls.push([start, end]);
      return { data: [{ id: "session", name: "Active" }], count: 1, error: null };
    } };
  } };
  const api = await load("sessions", db);
  assert.deepEqual(await api.loadAdmissionSessions("branch"), [{ id: "session", name: "Active" }]);
  assert.deepEqual(calls, [["sai_admissions_sessions", { wanted_branch: "branch" }, { count: "exact" }], [0, 999]]);
  db.rpc = () => ({ range: async () => ({ data: null, count: null, error: { message: "permission denied" } }) });
  await assert.rejects(api.loadAdmissionSessions("other"), /permission denied/);
  db.rpc = () => ({ range: async () => ({ data: [{ id: "session" }], count: 1, error: null }) });
  await assert.rejects(api.loadAdmissionSessions("branch"), /تعذر تحميل/);
});

test("queries require branch scope and apply filters and four-field search", async () => {
  const db = client({ data: [], count: 0, error: null });
  const api = await load("scope", db);
  assert.deepEqual(await api.loadAdmissions(filters), { rows: [], count: 0 });
  assert.equal(db.calls.length, 0);
  await api.loadAdmissions({ branch: "b", session: "s", status: "new", assignee: "u", search: 'A,B"_%', page: 1 });
  for (const [field, value] of [["branch_id", "b"], ["academic_session_id", "s"], ["status", "new"], ["assigned_to", "u"]]) {
    assert.ok(db.calls.some((call) => call[0] === "eq" && call[1] === field && call[2] === value));
  }
  const search = db.calls.find((call) => call[0] === "or")[1];
  for (const field of ["applicant_full_name", "guardian_name", "phone", "application_no"]) assert.ok(search.includes(`${field}.ilike.`));
  assert.ok(search.includes('\\"') && search.includes("\\_") && search.includes("\\%"));
  assert.ok(db.calls.some((call) => call[0] === "range" && call[1] === 25 && call[2] === 49));
});

test("query and denied writes surface errors and zero-row updates fail", async () => {
  const db = client({ data: null, count: null, error: { message: "permission denied" } });
  const api = await load("errors", db);
  const draft = api.admissionDraft(null, "b", "s"); draft.applicant_full_name = "Applicant";
  await assert.rejects(api.loadAdmissions({ ...filters, branch: "b" }), /permission denied/);
  await assert.rejects(api.saveAdmission(draft, null), /permission denied/);
  await assert.rejects(api.saveAdmission(draft, "id"), /permission denied/);
  db.from = () => ({ update: () => ({ eq: () => ({ select: async () => ({ data: [], error: null }) }) }) });
  await assert.rejects(api.saveAdmission(draft, "id"), /لم يُحدّث/);
});

test("admissions implementation has no deletion operation", () => {
  for (const file of ["../../src/portal/lib/admissions.ts", "../../src/portal/pages/Admissions.tsx", "../../supabase/migrations/004_admissions.sql"]) {
    const text = fs.readFileSync(path.join(__dirname, file), "utf8");
    assert.doesNotMatch(text, /\.delete\s*\(|\btruncate\b|\bdelete\s+from\b|\bdrop\b/i);
  }
});
