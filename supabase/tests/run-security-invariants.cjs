/*
 * Runner for the security invariant gate.
 *
 *   node supabase/tests/run-security-invariants.cjs
 *
 * Runs supabase/tests/security_invariants.sql through the local Supabase CLI
 * and exits non-zero when an invariant is broken, so CI (or a pre-push hook, or
 * a build step) fails instead of silently accepting a regression.
 *
 * Local only, by design: the assertion is read-only, but targeting an explicit
 * --local database keeps this identical in shape to run-wave1-local.cjs and
 * avoids ever pointing a test at production by accident.
 */

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const project = path.resolve(__dirname, "../..");
const source = fs.readFileSync(path.join(__dirname, "security_invariants.sql"), "utf8");

if (!/pg_depend/.test(source)) {
  console.error("Refusing to run: the invariant check must be dependency based (pg_depend).");
  process.exitCode = 1;
} else {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "sai-invariants-"));
  const tempFile = path.join(tempDir, "security_invariants.sql");
  try {
    fs.writeFileSync(tempFile, source, { mode: 0o600 });
    const executable = process.platform === "win32" ? "supabase.exe" : "supabase";
    const result = spawnSync(executable, ["db", "query", "--local", "--file", tempFile], {
      cwd: project,
      encoding: "utf8",
      timeout: 120000,
    });
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) {
      console.error(`Security invariant check could not run: ${result.error.message}`);
      process.exitCode = 1;
    } else {
      process.exitCode = result.status ?? 1;
    }
  } finally {
    if (fs.existsSync(tempFile)) fs.unlinkSync(tempFile);
    fs.rmdirSync(tempDir);
  }
}