import { readFileSync, readdirSync, statSync } from 'node:fs';
import { resolve } from 'node:path';
import { Buffer } from 'node:buffer';

export const productionRef = 'aeryusbrulqdxjdynwfh';
export const productionUrl = `https://${productionRef}.supabase.co`;
function hasProductionPublicKey(value) {
  if (/^sb_publishable_[A-Za-z0-9_-]+$/.test(value ?? '')) return true;
  const parts = value?.split('.');
  if (parts?.length !== 3) return false;
  try {
    const claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    return claims.role === 'anon' && claims.ref === productionRef;
  } catch {
    return false;
  }
}

export function assertProductionEnvironment(env, mode = 'production') {
  const isPreview = Boolean(env.IS_PREVIEW) || mode !== 'production';
  const target = env.VITE_SAI_TARGET ?? 'production';

  // A missing target is normal on hosted builds; only an explicit mismatch is an error.
  if (!isPreview && target !== 'production') {
    throw new Error('Production builds require the production target and mode.');
  }

  const url = env.VITE_PUBLIC_SUPABASE_URL?.replace(/\/$/, '');
  const key = env.VITE_PUBLIC_SUPABASE_ANON_KEY ?? '';

  // Missing configuration degrades the backend, it must not blank the public site.
  if (!isPreview && url && url !== productionUrl) {
    throw new Error('Production backend identity mismatch.');
  }
  if (!isPreview && key && !hasProductionPublicKey(key)) {
    throw new Error('Production clients require a public anon or publishable key for the authorized project.');
  }

  for (const [name, value] of Object.entries(env)) {
    if (name.startsWith('VITE_') && value && (/SERVICE_ROLE|SECRET|PASSWORD|PRIVATE_KEY|ADMIN_CREDENTIAL/i.test(name)
      || /sb_secret_|-----BEGIN .*PRIVATE KEY/.test(value))) {
      throw new Error('Private credential configuration cannot be exposed to a client build.');
    }
  }
}

const supabaseHost = new URL(productionUrl).host;
const supabaseWs = `wss://${productionRef}.supabase.co`;

export const securityHeaders = {
  'Content-Security-Policy': [
    "default-src 'self'",
    "base-uri 'self'",
    "object-src 'none'",
    "frame-ancestors 'self' https://readdy.ai https://*.readdy.ai",
    "script-src 'self' https://static.readdy.ai",
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com",
    "font-src 'self' data: https://fonts.gstatic.com https://cdnjs.cloudflare.com",
    `img-src 'self' data: blob: ${productionUrl} https://readdy.ai https://*.readdy.ai https://static.readdy.ai https://public.readdy.ai https://storage.readdy-site.link https://storage.helloreaddy.com`,
    `connect-src 'self' ${productionUrl} ${supabaseWs} https://static.readdy.ai https://api.vapi.ai`,
    `media-src 'self' blob: ${productionUrl}`,
    "worker-src 'self' blob:",
    "frame-src 'self' https://www.youtube-nocookie.com https://www.youtube.com https://player.vimeo.com",
    "form-action 'self' https://readdy.ai https://*.readdy.ai",
    'upgrade-insecure-requests',
  ].join('; '),
  'Strict-Transport-Security': 'max-age=31536000',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(self), microphone=(), geolocation=(), payment=()',
};

export function verifyProductionBundle(directory) {
  const files = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir)) {
      const path = resolve(dir, entry);
      if (statSync(path).isDirectory()) walk(path); else files.push(path);
    }
  };
  walk(directory);
  let approvedHost = false;
  for (const path of files) {
    if (/\.(?:map|jks|keystore|p12|pfx|pem|key)$/i.test(path)) throw new Error('Private or debug artifact in public output.');
    if (!/\.(?:cjs|css|html|js|json|mjs|svg|txt|webmanifest)$/i.test(path)) continue;
    const text = readFileSync(path, 'utf8');
    const hosts = text.match(/[a-z0-9-]+\.supabase\.co/gi) ?? [];
    if (hosts.some((host) => host !== supabaseHost)) throw new Error('Unauthorized backend in output.');
    approvedHost ||= hosts.includes(supabaseHost);
    if (/sb_secret_[A-Za-z0-9_-]+|-----BEGIN .*PRIVATE KEY-----/i.test(text)) throw new Error('Private credential in output.');
  }
  if (!approvedHost) throw new Error('Production backend absent from bundle.');
  return files;
}
