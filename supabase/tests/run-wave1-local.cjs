const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const requested = process.argv[2];
if (process.argv.length > 3 || (requested && requested !== "--admissions")) {
  console.error("Only --admissions is accepted; this test targets only Supabase CLI --local.");
  process.exitCode = 1;
} else {
  const project = path.resolve(__dirname, "../..");
  const filename = requested === "--admissions" ? "admissions_behavior.sql" : "wave1_management_behavior.sql";
  const source = fs.readFileSync(path.join(__dirname, filename), "utf8");
  if (!source.includes("begin;")) throw new Error("Missing test transaction");
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "wave1-local-test-"));
  const tempFile = path.join(tempDir, "wave1.sql");
  try {
    fs.writeFileSync(tempFile, source.replace("begin;", "begin;\nset local sai.wave1_isolated_test = 'yes';"), { mode: 0o600 });
    const executable = process.platform === "win32" ? "supabase.exe" : "supabase";
    const result = spawnSync(executable, ["db", "query", "--local", "--file", tempFile], {
      cwd: project,
      encoding: "utf8",
      timeout: 120000,
    });
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) {
      console.error(`Local database test could not run: ${result.error.message}`);
      process.exitCode = 1;
    } else {
      process.exitCode = result.status ?? 1;
    }
  } finally {
    if (fs.existsSync(tempFile)) fs.unlinkSync(tempFile);
    fs.rmdirSync(tempDir);
  }
}
