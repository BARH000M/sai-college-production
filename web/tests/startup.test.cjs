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

test("startup errors are explicit and configured authentication options are preserved", async () => {
  const errorUrl = await moduleUrl("lib/initializationError.ts");
  const { SupabaseInitializationError } = await import(errorUrl);
  const loadSupabase = async (env, createClient) => {
    globalThis.__startupEnv = env;
    globalThis.__startupCreateClient = createClient;
    const url = await moduleUrl("lib/supabase.ts", (source) => source
      .replace('import { createClient } from "@supabase/supabase-js";', "const createClient = globalThis.__startupCreateClient;")
      .replace('"./initializationError"', JSON.stringify(errorUrl))
      .replaceAll("import.meta.env", "globalThis.__startupEnv"));
    return import(`${url}#${Math.random()}`);
  };
  const prodEnv = { VITE_PUBLIC_SUPABASE_URL: "https://aeryusbrulqdxjdynwfh.supabase.co", VITE_PUBLIC_SUPABASE_ANON_KEY: "sb_publishable_test" };
  const prevEnv = {
    VITE_SAI_TARGET: "preview",
    VITE_PUBLIC_SUPABASE_URL: "https://mgibjusuglafbnlrkbep.supabase.co",
    VITE_PUBLIC_SUPABASE_ANON_KEY: "sb_publishable_test",
  };
  try {
    await assert.rejects(loadSupabase({}, () => assert.fail("must not create a client")), SupabaseInitializationError);
    const cause = new Error("invalid URL");
    await assert.rejects(
      loadSupabase(prodEnv, () => { throw cause; }),
      (error) => error instanceof SupabaseInitializationError && error.cause === cause,
    );
    const client = {};
    const result = await loadSupabase(
      prodEnv,
      (url, key, options) => {
        assert.equal(url, prodEnv.VITE_PUBLIC_SUPABASE_URL);
        assert.equal(key, prodEnv.VITE_PUBLIC_SUPABASE_ANON_KEY);
        assert.deepEqual(options.auth, {
          autoRefreshToken: true, detectSessionInUrl: true, persistSession: true,
          storageKey: "sai-production-auth",
        });
        return client;
      },
    );
    assert.equal(result.supabase, client);
    assert.equal(result.supabaseTarget, "production");

    // Preview mode: only the Preview project, with environment-scoped storage.
    const previewResult = await loadSupabase(prevEnv, (url, key, options) => {
      assert.equal(url, prevEnv.VITE_PUBLIC_SUPABASE_URL);
      assert.equal(options.auth.storageKey, "sai-preview-auth");
      return client;
    });
    assert.equal(previewResult.supabaseTarget, "preview");

    // Fail closed on every cross-project or unsupported combination.
    const prodJwt = `x.${Buffer.from(JSON.stringify({ role: "anon", ref: "aeryusbrulqdxjdynwfh" })).toString("base64url")}.x`;
    const prevJwt = `x.${Buffer.from(JSON.stringify({ role: "anon", ref: "mgibjusuglafbnlrkbep" })).toString("base64url")}.x`;
    for (const env of [
      { ...prodEnv, VITE_PUBLIC_SUPABASE_URL: "https://mgibjusuglafbnlrkbep.supabase.co" },
      { ...prodEnv, VITE_SAI_TARGET: "staging" },
      { ...prevEnv, VITE_PUBLIC_SUPABASE_URL: "https://aeryusbrulqdxjdynwfh.supabase.co" },
      { ...prevEnv, VITE_PUBLIC_SUPABASE_ANON_KEY: prodJwt },
      { ...prodEnv, VITE_PUBLIC_SUPABASE_ANON_KEY: prevJwt },
      { ...prodEnv, VITE_PUBLIC_SUPABASE_URL: "https://other.supabase.co" },
      { ...prodEnv, VITE_PUBLIC_SUPABASE_ANON_KEY: "sb_secret_private" },
      { ...prodEnv, VITE_PUBLIC_SUPABASE_ANON_KEY: `x.${Buffer.from(JSON.stringify({ role: "service_role", ref: "aeryusbrulqdxjdynwfh" })).toString("base64url")}.x` },
    ]) await assert.rejects(loadSupabase(env, () => assert.fail("must reject before client creation")), SupabaseInitializationError);
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
