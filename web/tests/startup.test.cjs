const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { transformWithOxc } = require("vite");
const React = require("react");
const { renderToStaticMarkup } = require("react-dom/server");

async function moduleUrl(file, replace = (source) => source) {
  const filePath = path.join(__dirname, "../../src/portal", file);
  const source = replace(fs.readFileSync(filePath, "utf8"));
  const { code } = await transformWithOxc(source, filePath, {});
  return `data:text/javascript;base64,${Buffer.from(code).toString("base64")}`;
}

const PRODUCTION = "https://aeryusbrulqdxjdynwfh.supabase.co";
const PLACEHOLDER = "sb_publishable_unconfigured";

test("startup stays renderable and never connects to an unauthorized backend", async () => {
  const loadSupabase = async (env, createClient) => {
    globalThis.__startupEnv = env;
    globalThis.__startupCreateClient = createClient;
    const url = await moduleUrl("lib/supabase.ts", (source) => source
      .replace('import { createClient } from "@supabase/supabase-js";', "const createClient = globalThis.__startupCreateClient;")
      .replaceAll("import.meta.env", "globalThis.__startupEnv"));
    return import(`${url}#${Math.random()}`);
  };
  const prodEnv = {
    VITE_SAI_TARGET: "production",
    VITE_PUBLIC_SUPABASE_URL: PRODUCTION,
    VITE_PUBLIC_SUPABASE_ANON_KEY: "sb_publishable_test",
  };
  const prevEnv = {
    VITE_SAI_TARGET: "preview",
    VITE_PUBLIC_SUPABASE_URL: "https://mgibjusuglafbnlrkbep.supabase.co",
    VITE_PUBLIC_SUPABASE_ANON_KEY: "sb_publishable_test",
  };
  const prodJwt = `x.${Buffer.from(JSON.stringify({ role: "anon", ref: "aeryusbrulqdxjdynwfh" })).toString("base64url")}.x`;
  const prevJwt = `x.${Buffer.from(JSON.stringify({ role: "anon", ref: "mgibjusuglafbnlrkbep" })).toString("base64url")}.x`;
  try {
    // A valid deployment keeps every configured authentication option.
    const client = {};
    let seen = null;
    const result = await loadSupabase(prodEnv, (url, key, options) => {
      seen = { url, key, options };
      return client;
    });
    assert.equal(result.isSupabaseConfigured, true);
    assert.equal(result.supabaseConfigurationError, null);
    assert.equal(result.supabase, client);
    assert.equal(result.supabaseTarget, "production");
    assert.deepEqual(seen.url, PRODUCTION);
    assert.equal(seen.key, "sb_publishable_test");
    assert.deepEqual(seen.options.auth, {
      autoRefreshToken: true, detectSessionInUrl: true, persistSession: true,
      storageKey: "sai-production-auth",
    });

    // Every rejected configuration still renders and falls back to the
    // authorized project with a non-usable key, never to another backend.
    const rejectedCases = [
      ["no environment at all", {}],
      ["retired target", prevEnv],
      ["unsupported target", { ...prodEnv, VITE_SAI_TARGET: "staging" }],
      ["retired project url", { ...prodEnv, VITE_PUBLIC_SUPABASE_URL: "https://mgibjusuglafbnlrkbep.supabase.co" }],
      ["foreign project url", { ...prodEnv, VITE_PUBLIC_SUPABASE_URL: "https://other.supabase.co" }],
      ["foreign project key", { ...prodEnv, VITE_PUBLIC_SUPABASE_ANON_KEY: prevJwt }],
      ["malformed url", { ...prodEnv, VITE_PUBLIC_SUPABASE_URL: "not-a-url" }],
      ["secret key", { ...prodEnv, VITE_PUBLIC_SUPABASE_ANON_KEY: "sb_secret_private" }],
      ["service role key", {
        ...prodEnv,
        VITE_PUBLIC_SUPABASE_ANON_KEY: `x.${Buffer.from(JSON.stringify({ role: "service_role", ref: "aeryusbrulqdxjdynwfh" })).toString("base64url")}.x`,
      }],
      ["missing key", { VITE_SAI_TARGET: "production", VITE_PUBLIC_SUPABASE_URL: PRODUCTION }],
    ];
    for (const [label, env] of rejectedCases) {
      const fallback = await loadSupabase(env, (url, key) => {
        assert.equal(url, PRODUCTION, `${label}: url must stay authorized`);
        assert.equal(key, PLACEHOLDER, `${label}: placeholder key expected`);
        return {};
      });
      assert.equal(fallback.isSupabaseConfigured, false, `${label}: must not be usable`);
      assert.ok(fallback.supabaseConfigurationError, `${label}: reason required`);
    }

    // Legacy anon JWTs for the authorized project still work.
    const jwtResult = await loadSupabase(
      { ...prodEnv, VITE_PUBLIC_SUPABASE_ANON_KEY: prodJwt },
      () => (),
    );
    assert.equal(jwtResult.isSupabaseConfigured, true);
  } finally {
    delete globalThis.__startupEnv;
    delete globalThis.__startupCreateClient;
  }
});

test("Arabic branded boundary distinguishes startup failures from rendering errors", async () => {
  const errorUrl = await moduleUrl("lib/initializationError.ts");
  const { SupabaseInitializationError } = await import(errorUrl);
  const boundaryUrl = await moduleUrl("components/ErrorBoundary.tsx", (source) => source
    .replace('"react"', JSON.stringify(pathToFileURL(require.resolve("react")).href))
    .replace('import logo from "../assets/saiLogo";', 'const logo = "logo.png";')
    .replace('"../lib/initializationError"', JSON.stringify(errorUrl)));
  const reactJsxUrl = pathToFileURL(require.resolve("react/jsx-runtime")).href;
  const source = Buffer.from(boundaryUrl.split(",")[1], "base64").toString("utf8")
    .replace('"react/jsx-runtime"', JSON.stringify(reactJsxUrl));
  const { ErrorBoundary } = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`);
  for (const [error, heading] of [
    [new SupabaseInitializationError("private detail"), "تعذر إعداد الاتصال بالنظام"],
    [new Error("private detail"), "تعذر عرض الصفحة"],
    [null, "تعذر عرض الصفحة"],
  ]) {
    const boundary = new ErrorBoundary({ children: React.createElement("p", null, "content") });
    boundary.state = ErrorBoundary.getDerivedStateFromError(error);
    const html = renderToStaticMarkup(boundary.render());
    assert.match(html, new RegExp(heading));
    assert.match(html, /role="alert"/);
    assert.match(html, /شعار كلية ساي/);
    assert.doesNotMatch(html, /private detail/);
  }
});