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
  try {
    await assert.rejects(loadSupabase({}, () => assert.fail("must not create a client")), SupabaseInitializationError);
    const cause = new Error("invalid URL");
    await assert.rejects(
      loadSupabase(      { VITE_PUBLIC_SUPABASE_URL: "invalid", VITE_PUBLIC_SUPABASE_ANON_KEY: "key" }, () => { throw cause; }),
      (error) => error instanceof SupabaseInitializationError && error.cause === cause,
    );
    const client = {};
    const result = await loadSupabase(
      { VITE_PUBLIC_SUPABASE_URL: "https://example.invalid", VITE_PUBLIC_SUPABASE_ANON_KEY: "key" },
      (url, key, options) => {
        assert.equal(url, "https://example.invalid");
        assert.equal(key, "key");
        assert.deepEqual(options.auth, { autoRefreshToken: true, detectSessionInUrl: true, persistSession: true });
        return client;
      },
    );
    assert.equal(result.supabase, client);
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
