import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const read = (file) => fs.readFileSync(root + file, 'utf8');
const ref = 'aeryusbrulqdxjdynwfh';
test('all workspace MCP clients share the Main-only read-only endpoint', () => {
  const clients = [JSON.parse(read('.mcp.json')).mcpServers, JSON.parse(read('.vscode/mcp.json')).servers];
  for (const client of clients) {
    assert.deepEqual(Object.keys(client), ['supabase-main']);
    const url = new URL(client['supabase-main'].url);
    assert.equal(url.hostname, 'mcp.supabase.com');
    assert.equal(url.searchParams.get('project_ref'), ref);
    assert.equal(url.searchParams.get('read_only'), 'true');
    assert.equal(client['supabase-main'].headers, undefined);
  }
  const codex = read('.codex/config.toml');
  assert.match(codex, /\[mcp_servers.supabase-main\]/);
  assert.ok(codex.includes(`project_ref=${ref}&read_only=true`));
  assert.doesNotMatch(codex, /supabase-preview/);
});
test('web, mobile and VS Code launch cannot select a retired backend', () => {
  const web = read('src/portal/lib/supabase.ts');
  const mobile = read('mobile/lib/data/repository.dart');
  assert.ok(web.includes(ref)); assert.ok(mobile.includes(ref));
  assert.doesNotMatch(web + mobile, /mgibjusuglafbnlrkbep|_previewRef|targets\[supabaseTarget\]/);
  assert.match(web, /saiTarget !== undefined && saiTarget !== "production"/);
  assert.match(read('mobile/lib/main.dart'), /if \(saiTarget != 'production'\)/);
  assert.match(read('web/src/lib/supabase.ts'), /export \{ supabase, supabaseTarget \} from/);
  const launch = JSON.parse(read('.vscode/launch.json')).configurations[0];
  assert.deepEqual(launch.toolArgs, ['--dart-define-from-file=config/live.json']);
  const example = JSON.parse(read('mobile/config/live.example.json'));
  assert.equal(example.SAI_TARGET, 'production'); assert.equal(example.SAI_PREVIEW, 'false');
  assert.equal(example.SUPABASE_PUBLIC_KEY, 'PASTE_PUBLIC_KEY_HERE');
});
test('both push workflows remain checks-only, without deployment credentials or commands', () => {
  for (const file of ['.github/workflows/web-ci.yml', '.github/workflows/mobile-ci.yml']) {
    const workflow = read(file);
    assert.match(workflow, /contents: read/);
    assert.doesNotMatch(workflow, /supabase (?:db push|functions deploy)|vercel|netlify|SUPABASE_ACCESS_TOKEN|SUPABASE_SERVICE_ROLE|environment: production/);
  }
});

test('root React app owns the production build and secondary web commands delegate to it', () => {
  const rootPackage = JSON.parse(read('package.json'));
  const webPackage = JSON.parse(read('web/package.json'));
  assert.equal(rootPackage.scripts.build, 'vite build');
  assert.equal(webPackage.scripts.build, 'npm --prefix .. run build');
  assert.equal(webPackage.scripts.preview, 'npm --prefix .. run preview');
  assert.match(read('vite.config.ts'), /outDir:\s*['"]out['"]/);

  const workflow = read('.github/workflows/web-ci.yml');
  const productionJob = workflow.split('  secondary-web:')[0];
  assert.match(productionJob, /- run: npm run build/);
  assert.match(workflow, /root app is built in main-web/);
});
