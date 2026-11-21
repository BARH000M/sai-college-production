const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..", "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");

const modules = [
  { id: "media", file: "src/portal/pages/MediaLibrary.tsx", component: "MediaLibrary", storage: '"media"' },
  { id: "approvals", file: "src/portal/pages/ContentApprovals.tsx", component: "ContentApprovals", storage: '"approvals"' },
  { id: "quizzes", file: "src/portal/pages/Quizzes.tsx", component: "Quizzes", storage: '"quizzes"' },
  { id: "reception", file: "src/portal/pages/Reception.tsx", component: "Reception", storage: '"reception"' },
];

test("every V4.0 module page exports its screen component", () => {
  for (const entry of modules) {
    const source = read(entry.file);
    assert.match(source, new RegExp(`export function ${entry.component}\\b`), `${entry.id} must export ${entry.component}`);
    assert.match(source, /useLocalWorkspace\(/, `${entry.id} must persist its workspace state`);
    assert.match(source, new RegExp(entry.storage.replace(/"/g, '\\"')), `${entry.id} must use its own storage key`);
  }
});

test("the module entry router wires all four screens", () => {
  const entry = read("src/portal/pages/ModuleEntry.tsx");
  for (const item of modules) {
    assert.match(entry, new RegExp(`import \\{ ${item.component} \\}`), `${item.id} must be imported`);
    assert.match(entry, new RegExp(`item\\.id === "${item.id}"`), `${item.id} must have a route branch`);
  }
});

test("navigation exposes the four modules and no longer lists them as pending", () => {
  const navigation = read("src/portal/lib/navigation.ts");
  const available = navigation.match(/availableModuleIds[^=]*=\s*\[([\s\S]*?)\];/)[1];
  for (const item of modules) assert.ok(available.includes(`"${item.id}"`), `${item.id} must be available`);
  const pending = navigation.match(/pendingModules[^=]*=\s*\[([\s\S]*?)\] as const;/)[1];
  for (const item of modules) assert.doesNotMatch(pending, new RegExp(`id: "${item.id}"`), `${item.id} must not be pending`);
});

test("the workspace stylesheet is imported by the portal root", () => {
  const app = read("src/portal/AppRoot.tsx");
  assert.match(app, /workspace-modules\.css/);
});

test("reception conversion links to the admissions module and never duplicates a phone number", () => {
  const source = read("src/portal/pages/Reception.tsx");
  assert.match(source, /\/portal\/modules\/admissions/);
  assert.match(source, /replace\(\/\\D\/g, ""\)/, "duplicate detection must compare normalised phone numbers");
});

test("content approvals block self-approval when the policy is on", () => {
  const source = read("src/portal/pages/ContentApprovals.tsx");
  assert.match(source, /selfApprovalBlocked/);
  assert.match(source, /selected\.author === actor/, "self approval must be detected by author identity");
});

test("quiz delivery never renders the answer key", () => {
  const source = read("src/portal/pages/Quizzes.tsx");
  const delivery = source.slice(source.indexOf('tab === "take"'), source.indexOf('tab === "results"'));
  assert.ok(delivery.length > 0);
  assert.doesNotMatch(delivery, /question\.correct/, "the delivery screen must not expose correct answers");
});