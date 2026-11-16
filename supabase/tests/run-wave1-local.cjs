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
  const filenames = requested === "--admissions"
    ? ["admissions_behavior.sql", "admissions_tracking_behavior.sql", "admission_event_integrity.sql", "student_parent_access.sql"]
    : ["wave1_management_behavior.sql"];
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "wave1-local-test-"));
  try {
    const executable = process.platform === "win32" ? "supabase.exe" : "supabase";
    for (const filename of filenames) {
      const source = fs.readFileSync(path.join(__dirname, filename), "utf8");
      if (!source.includes("begin;")) throw new Error(`Missing test transaction in ${filename}`);
      const tempFile = path.join(tempDir, filename);
      fs.writeFileSync(tempFile, source.replace("begin;", "begin;\nset local sai.wave1_isolated_test = 'yes';"), { mode: 0o600 });
      const result = spawnSync(executable, ["db", "query", "--local", "--file", tempFile], {
        cwd: project,
        encoding: "utf8",
        timeout: 120000,
      });
      if (result.stdout) process.stdout.write(result.stdout);
      if (result.stderr) process.stderr.write(result.stderr);
      if (result.error) {
        console.error(`Local database test could not run ${filename}: ${result.error.message}`);
        process.exitCode = 1;
        break;
      }
      if (result.status !== 0) {
        process.exitCode = result.status ?? 1;
        break;
      }
    }
  } finally {
    for (const filename of filenames) {
      const tempFile = path.join(tempDir, filename);
      if (fs.existsSync(tempFile)) fs.unlinkSync(tempFile);
    }
    fs.rmdirSync(tempDir);
  }
}
