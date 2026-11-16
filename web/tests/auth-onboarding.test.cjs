const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const root = path.resolve(__dirname, "../..");
const source = fs.readFileSync(path.join(root, "src/portal/lib/auth.ts"), "utf8")
  .replace('import { supabase } from "./supabase";', "const supabase = globalThis.__authOnboardingTestClient;");
const code = stripTypeScriptTypes(source, { mode: "strip" });

test("profile initialization uses only client-insertable columns and reports the confirmed email state", async () => {
  let insertedProfile = null;
  const client = {
    auth: {
      signInWithPassword: async () => ({
        data: {
          session: {
            user: {
              id: "user-1",
              email: "student@example.test",
              email_confirmed_at: "2026-01-01T00:00:00.000Z",
              user_metadata: { full_name: "Student", preferred_locale: "ar" },
            },
          },
        },
        error: null,
      }),
    },
    schema: () => ({
      from(table) {
        let selected = "";
        const query = {
          select(columns) { selected = columns; return query; },
          eq() { return query; },
          maybeSingle: async () => ({
            data: table === "profiles" && selected === "full_name" ? { full_name: "Student" } : null,
            error: null,
          }),
          insert(values) { insertedProfile = values; return Promise.resolve({ error: null }); },
          then(resolve, reject) { return Promise.resolve({ data: [], error: null }).then(resolve, reject); },
        };
        return query;
      },
    }),
  };
  globalThis.__authOnboardingTestClient = client;
  const auth = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}#${Math.random()}`);
  const state = await auth.signIn("student@example.test", "not-a-real-password");

  assert.equal(state.status, "signed-in");
  assert.equal(state.emailConfirmed, true);
  assert.equal(state.profile.fullName, "Student");
  assert.deepEqual(Object.keys(insertedProfile).sort(), ["full_name", "id", "preferred_locale"]);
  assert.equal("email" in insertedProfile, false);
});
