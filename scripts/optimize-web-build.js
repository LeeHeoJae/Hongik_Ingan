const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const projectRoot = path.resolve(__dirname, '..');
const releaseManifestName = 'web-release-manifest.json';
const logoPath = 'assets/assets/images/icon_foreground.png';

// Retain exactly the previous release, including assets an old tab has not loaded.
async function optimizeWebBuild({
  webBuildDir = path.join(projectRoot, 'build', 'web'),
  previousBaseUrl,
  fetchImpl = fetch,
} = {}) {
  const precache = JSON.parse(fs.readFileSync(path.join(webBuildDir, 'precache_manifest.json'), 'utf8'));
  if (precache.version !== 1 || !Array.isArray(precache.entries)) throw new Error('Invalid Flutter manifest.');
  const files = precache.entries.filter((entry) => entry.urlHashed).map((entry) => {
    validatePath(entry.url);
    const bytes = fs.readFileSync(path.join(webBuildDir, entry.url));
    const hash = digest(bytes);
    if (hash.slice(0, 8) !== entry.hash) throw new Error('Content hash mismatch: ' + entry.url);
    return { url: entry.url, hash, size: bytes.length };
  });
  if (!files.some((entry) => /^main\.dart\.[a-f0-9]{8}\.wasm$/.test(entry.url))) {
    throw new Error('Expected a content-hashed Flutter Wasm build.');
  }
  const logo = files.find((entry) => originalAssetPath(entry) === logoPath);
  if (!logo) throw new Error('Hashed bootstrap logo is missing.');
  for (const name of ['index.html', 'offline.html']) {
    const filename = path.join(webBuildDir, name);
    fs.writeFileSync(filename, fs.readFileSync(filename, 'utf8').replaceAll(logoPath, logo.url), 'utf8');
  }
  const previous = previousBaseUrl
    ? await retainPreviousRelease(webBuildDir, previousBaseUrl, files, fetchImpl) : [];
  // Compatibility aliases for pre-hash tabs and their old service worker.
  if (previousBaseUrl && previous.length === 0) {
    for (const entry of files.filter((entry) => entry.url.startsWith('assets/'))) {
      fs.copyFileSync(path.join(webBuildDir, entry.url), path.join(webBuildDir, originalAssetPath(entry)));
    }
  }
  const template = fs.readFileSync(path.join(projectRoot, 'web', 'app_service_worker.js'), 'utf8');
  const hashedPaths = [...new Set([...files, ...previous].map((entry) => '/' + entry.url))].sort();
  const hash = crypto.createHash('sha256').update(JSON.stringify(files)).update(template).update(JSON.stringify(hashedPaths));
  for (const entry of precache.entries.filter((entry) => !entry.urlHashed &&
      !['app_service_worker.js', releaseManifestName].includes(entry.url))) {
    validatePath(entry.url);
    hash.update(entry.url).update(fs.readFileSync(path.join(webBuildDir, entry.url)));
  }
  const buildVersion = hash.digest('hex').slice(0, 16);
  const worker = template.replaceAll('__HONGIK_INGAN_BUILD_VERSION__', buildVersion)
    .replace('/*__HONGIK_HASHED_PATHS__*/ []', JSON.stringify(hashedPaths)).replaceAll(logoPath, logo.url);
  fs.writeFileSync(path.join(webBuildDir, 'app_service_worker.js'), worker, 'utf8');
  // Publish current files only: the next build must not accumulate older releases.
  fs.writeFileSync(path.join(webBuildDir, releaseManifestName), JSON.stringify({ version: 1, files }), 'utf8');
  for (const entry of precache.entries) {
    const bytes = fs.readFileSync(path.join(webBuildDir, entry.url));
    entry.hash = digest(bytes).slice(0, 8);
    entry.size = bytes.length;
  }
  fs.writeFileSync(path.join(webBuildDir, 'precache_manifest.json'), JSON.stringify(precache, null, 2), 'utf8');
  console.log('[web-build] Cache version: ' + buildVersion + '; ' + files.length + ' current, ' + previous.length + ' previous hashed files');
  return { files, previous, buildVersion };
}

async function retainPreviousRelease(webBuildDir, baseUrl, current, fetchImpl) {
  const base = new URL(baseUrl);
  if (base.protocol !== 'https:' || base.pathname !== '/' || base.search || base.hash || base.username || base.password) {
    throw new Error('Previous release URL must be an HTTPS origin.');
  }
  const response = await fetchImpl(new URL(releaseManifestName, base), fetchOptions());
  if (response.status === 404) return [];
  if (!response.ok) throw new Error('Previous manifest request failed: ' + response.status);
  const text = await response.text();
  // The pre-hash deployment's SPA catch-all returns HTML for a missing manifest.
  if (/^\s*<!doctype html/i.test(text) && text.includes('flutter_bootstrap.js')) return [];
  const manifest = JSON.parse(text);
  if (manifest.version !== 1 || !Array.isArray(manifest.files) || manifest.files.length > 2000) {
    throw new Error('Invalid previous release manifest.');
  }
  for (const entry of manifest.files) {
    validatePath(entry.url);
    if (!/^[a-f0-9]{64}$/.test(entry.hash) || !Number.isSafeInteger(entry.size) || entry.size < 0 ||
        entry.size > 64 * 1024 * 1024 || !(entry.url.startsWith('assets/') || /^main\.dart\./.test(entry.url)) ||
        !new RegExp('\\.' + entry.hash.slice(0, 8) + '(?:\\.[^/]+)?$').test(entry.url)) throw new Error('Invalid previous asset: ' + entry.url);
  }
  const currentByUrl = new Map(current.map((entry) => [entry.url, entry]));
  const pending = manifest.files.slice();
  await Promise.all(Array.from({ length: Math.min(4, pending.length) }, async () => {
    while (pending.length) {
      const entry = pending.pop();
      const existing = currentByUrl.get(entry.url);
      if (existing) {
        if (existing.hash !== entry.hash || existing.size !== entry.size) throw new Error('Hash collision: ' + entry.url);
        continue;
      }
      const asset = await fetchImpl(new URL(entry.url, base), fetchOptions());
      if (!asset.ok) throw new Error('Previous asset request failed: ' + entry.url + ' (' + asset.status + ')');
      const bytes = Buffer.from(await asset.arrayBuffer());
      if (bytes.length !== entry.size || digest(bytes) !== entry.hash) {
        throw new Error('Previous asset integrity check failed: ' + entry.url);
      }
      const destination = path.join(webBuildDir, entry.url);
      fs.mkdirSync(path.dirname(destination), { recursive: true });
      fs.writeFileSync(destination, bytes);
    }
  }));
  return manifest.files;
}

function validatePath(url) {
  if (typeof url !== 'string' || !/^[A-Za-z0-9_./-]+$/.test(url) || url.startsWith('/') ||
      url.split('/').some((part) => !part || part === '.' || part === '..')) {
    throw new Error('Unsafe asset path: ' + url);
  }
}

function originalAssetPath(entry) {
  return entry.url.replace(new RegExp('\\.' + entry.hash.slice(0, 8) + '(?=\\.[^/]+$|$)'), '');
}
function digest(bytes) { return crypto.createHash('sha256').update(bytes).digest('hex'); }
function fetchOptions() { return { cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(30_000) }; }

if (require.main === module) {
  const previousBaseUrl = process.env.VERCEL_ENV === 'production'
    ? 'https://' + (process.env.VERCEL_PROJECT_PRODUCTION_URL || 'hongik-ingan.vercel.app') : undefined;
  optimizeWebBuild({ previousBaseUrl }).catch((error) => {
    console.error('[web-build] ' + error.message);
    process.exitCode = 1;
  });
}
module.exports = { optimizeWebBuild };
