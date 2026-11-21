const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { stripTypeScriptTypes } = require("node:module");

const LIB = path.join(__dirname, "../../src/portal/lib");
const COMPONENTS = path.join(__dirname, "../../src/portal/components");
const PORTAL = path.join(__dirname, "../../src/portal");

function toDataUrl(source) {
  const code = stripTypeScriptTypes(source, { mode: "strip" });
  return `data:text/javascript;base64,${Buffer.from(code).toString("base64")}`;
}

const langUrl = toDataUrl(fs.readFileSync(path.join(LIB, "portalLang.ts"), "utf8"));
const langModule = import(langUrl);

test("Arabic is right-to-left and English/Chinese are left-to-right", async () => {
  const lang = await langModule;
  assert.equal(lang.directionFor("ar"), "rtl");
  assert.equal(lang.directionFor("en"), "ltr");
  assert.equal(lang.directionFor("zh"), "ltr");
  for (const entry of lang.portalLanguages) {
    assert.equal(entry.dir, lang.directionFor(entry.id), `${entry.id} declares a mismatched direction`);
  }
});

test("every translated dictionary entry is complete in all three languages", async () => {
  const lang = await langModule;
  const dictionaries = {
    navLabels: lang.navLabels,
    moduleLabels: lang.moduleLabels,
    sectionLabels: lang.sectionLabels,
    zoneLabels: lang.zoneLabels,
    statusLabels: lang.statusLabels,
    uiStrings: lang.uiStrings,
  };
  for (const [name, dictionary] of Object.entries(dictionaries)) {
    for (const [key, entry] of Object.entries(dictionary)) {
      assert.equal(entry.length, 3, `${name}.${key} must have exactly three translations`);
      for (const value of entry) {
        assert.ok(
          typeof value === "string" && value.trim().length > 0,
          `${name}.${key} has an empty translation`,
        );
      }
    }
  }
});

test("no dictionary key is declared twice in the source", async () => {
  const source = fs.readFileSync(path.join(LIB, "portalLang.ts"), "utf8");
  // Split the file into the dictionary blocks and look for duplicate keys inside one block.
  const blocks = source.split(/\nexport const |\nfunction pick/);
  for (const block of blocks) {
    const keys = [...block.matchAll(/^ {2}([A-Za-z_][\w]*):\s*\[/gm)].map((match) => match[1]);
    const duplicates = keys.filter((key, index) => keys.indexOf(key) !== index);
    assert.deepEqual(duplicates, [], `duplicate dictionary keys: ${duplicates.join(", ")}`);
  }
});

test("portal stylesheets never hardcode a physical direction", async () => {
  const files = ["styles.css", "components/role-sidebar.css", "components/portal-redesign.css", "components/workspace-modules.css"];
  for (const file of files) {
    const css = fs.readFileSync(path.join(PORTAL, file), "utf8");
    // `direction: rtl` is only allowed on the explicit [dir="rtl"] selector.
    const directionLines = css
      .split("\n")
      .map((line, index) => ({ line: line.trim(), number: index + 1 }))
      .filter(({ line }) => /^direction:\s*(rtl|ltr)/.test(line));
    assert.equal(directionLines.length, 0, `${file} must not set direction directly`);

    for (const { line, number } of css.split("\n").map((line, index) => ({ line, number: index + 1 }))) {
      const trimmed = line.trim();
      if (trimmed.startsWith("/*") || trimmed.startsWith("*")) continue;
      assert.ok(
        !/(^|\s)(margin|padding)-(left|right):/.test(trimmed),
        `${file}:${number} uses a physical margin/padding: ${trimmed}`,
      );
      assert.ok(
        !/(^|\s)(left|right):\s*-?\d/.test(trimmed),
        `${file}:${number} uses a physical offset: ${trimmed}`,
      );
      assert.ok(
        !/text-align:\s*(left|right);/.test(trimmed),
        `${file}:${number} uses a physical text alignment: ${trimmed}`,
      );
      assert.ok(
        !/border-(left|right):/.test(trimmed),
        `${file}:${number} uses a physical border: ${trimmed}`,
      );
    }
  }
});

test("the portal root is the single direction surface", async () => {
  const appRoot = fs.readFileSync(path.join(PORTAL, "AppRoot.tsx"), "utf8");
  assert.ok(/dir=\{dir\}/.test(appRoot), "the portal root must bind dir to the active language");
  assert.ok(/usePortalLang\(\)/.test(appRoot), "the portal root must read the language context");
  assert.ok(!/className="portal-root"/.test(appRoot), "every portal-root render must set dir");

  const styles = fs.readFileSync(path.join(PORTAL, "styles.css"), "utf8");
  assert.ok(/\.portal-root\[dir="rtl"\]\s*\{\s*direction:\s*rtl;\s*\}/.test(styles));
  assert.ok(/\.portal-root\[dir="ltr"\]\s*\{\s*direction:\s*ltr;\s*\}/.test(styles));
});

test("pages never force their own writing direction", async () => {
  const offenders = [];
  function walk(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const full = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.name.endsWith(".tsx")) {
        const source = fs.readFileSync(full, "utf8");
        if (/dir="rtl"/.test(source)) offenders.push(path.relative(PORTAL, full));
      }
    }
  }
  walk(PORTAL);
  assert.deepEqual(offenders, [], "pages must inherit direction from the portal root");
});