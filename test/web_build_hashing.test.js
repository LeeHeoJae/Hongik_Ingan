const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { optimizeWebBuild } = require('../scripts/optimize-web-build');

function fixture(t, version) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'hongik-web-hash-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const entries = [];
  function write(url, body, hashed = false) {
    const hash = crypto.createHash('sha256').update(body).digest('hex');
    if (hashed) url = url.replace(/(\.[^/.]+)$/, '.' + hash.slice(0, 8) + '$1');
    const filename = path.join(dir, url);
    fs.mkdirSync(path.dirname(filename), { recursive: true });
    fs.writeFileSync(filename, body, 'utf8');
    entries.push({ url, hash: hash.slice(0, 8), size: Buffer.byteLength(body), urlHashed: hashed });
  }
  write('main.dart.wasm', 'wasm-' + version, true);
  write('main.dart.mjs', 'module-' + version, true);
  write('main.dart.js', 'js-' + version, true);
  write('assets/assets/images/icon_foreground.png', 'shared-logo', true);
  write('assets/assets/fonts/Pretendard-Regular.otf', 'shared-font', true);
  write('index.html', '<img src="assets/assets/images/icon_foreground.png">');
  write('offline.html', '<img src="/assets/assets/images/icon_foreground.png">');
  write('flutter_bootstrap.js', 'bootstrap-' + version);
  write('keyboard_diagnostics.js', 'diagnostics');
  write('app_service_worker.js', 'placeholder');
  fs.writeFileSync(path.join(dir, 'precache_manifest.json'), JSON.stringify({ version: 1, entries }));
  return dir;
}

function published(dir) {
  return async (url) => {
    const file = path.join(dir, new URL(url).pathname.slice(1));
    return fs.existsSync(file) ? new Response(fs.readFileSync(file)) : new Response('', { status: 404 });
  };
}

test('hashed build links the bootstrap/offline logo and refreshes manifest integrity', async (t) => {
  const dir = fixture(t, 'a');
  const result = await optimizeWebBuild({ webBuildDir: dir });
  const logo = result.files.find((entry) => entry.url.endsWith('.png')).url;
  for (const name of ['index.html', 'offline.html', 'app_service_worker.js']) {
    const source = fs.readFileSync(path.join(dir, name), 'utf8');
    assert.ok(source.includes(logo), name);
    assert.ok(!source.includes('__HONGIK_INGAN_BUILD_VERSION__'), name);
  }
  const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'precache_manifest.json'), 'utf8'));
  for (const entry of manifest.entries) {
    const bytes = fs.readFileSync(path.join(dir, entry.url));
    assert.equal(entry.hash, crypto.createHash('sha256').update(bytes).digest('hex').slice(0, 8));
    assert.equal(entry.size, bytes.length);
  }
  assert.equal((await optimizeWebBuild({ webBuildDir: dir })).buildVersion, result.buildVersion);
});

test('two deployments retain a previous uncached lazy asset but do not accumulate older releases', async (t) => {
  const a = fixture(t, 'a');
  const b = fixture(t, 'b');
  const c = fixture(t, 'c');
  const first = await optimizeWebBuild({ webBuildDir: a });
  const second = await optimizeWebBuild({ webBuildDir: b, previousBaseUrl: 'https://app.example', fetchImpl: published(a) });
  const third = await optimizeWebBuild({ webBuildDir: c, previousBaseUrl: 'https://app.example', fetchImpl: published(b) });
  for (const entry of first.files) assert.equal(fs.existsSync(path.join(b, entry.url)), true);
  for (const entry of second.files) assert.equal(fs.existsSync(path.join(c, entry.url)), true);
  const oldCode = first.files.find((entry) => entry.url.startsWith('main.dart.') && entry.url.endsWith('.js'));
  assert.equal(fs.existsSync(path.join(c, oldCode.url)), false);
  assert.equal(third.previous.length, second.files.length);
  const manifest = JSON.parse(fs.readFileSync(path.join(b, 'web-release-manifest.json'), 'utf8'));
  assert.deepEqual(manifest.files, second.files);
});

test('first rollout handles the old SPA manifest fallback and keeps legacy asset aliases', async (t) => {
  const dir = fixture(t, 'a');
  await optimizeWebBuild({ webBuildDir: dir, previousBaseUrl: 'https://app.example',
    fetchImpl: async () => new Response('<!DOCTYPE html><html><script src="flutter_bootstrap.js"></script></html>') });
  assert.equal(fs.readFileSync(path.join(dir, 'assets/assets/images/icon_foreground.png'), 'utf8'), 'shared-logo');
});

test('a failed previous deployment fetch aborts the build', async (t) => {
  await assert.rejects(optimizeWebBuild({ webBuildDir: fixture(t, 'b'), previousBaseUrl: 'https://app.example',
    fetchImpl: async () => new Response('unavailable', { status: 503 }) }), /Previous manifest request failed/);
});

test('an authentication or error HTML page is not mistaken for a pre-hash deployment', async (t) => {
  await assert.rejects(optimizeWebBuild({ webBuildDir: fixture(t, 'b'), previousBaseUrl: 'https://app.example',
    fetchImpl: async () => new Response('<!DOCTYPE html><html>Sign in</html>') }));
});

test('unhashed shell changes invalidate the worker shell version', async (t) => {
  const dir = fixture(t, 'a');
  const manifestPath = path.join(dir, 'precache_manifest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  fs.mkdirSync(path.join(dir, 'icons'));
  fs.writeFileSync(path.join(dir, 'icons/Icon-192.png'), 'icon-a');
  manifest.entries.push({ url: 'icons/Icon-192.png', urlHashed: false });
  fs.writeFileSync(manifestPath, JSON.stringify(manifest));
  const a = await optimizeWebBuild({ webBuildDir: dir });
  fs.writeFileSync(path.join(dir, 'icons/Icon-192.png'), 'icon-b');
  const b = await optimizeWebBuild({ webBuildDir: dir });
  assert.notEqual(a.buildVersion, b.buildVersion);
});

test('a corrupt previous asset aborts the build instead of serving mismatched code', async (t) => {
  const a = fixture(t, 'a');
  await optimizeWebBuild({ webBuildDir: a });
  const get = published(a);
  await assert.rejects(optimizeWebBuild({ webBuildDir: fixture(t, 'b'), previousBaseUrl: 'https://app.example',
    fetchImpl: (url) => String(url).endsWith('web-release-manifest.json') ? get(url) : new Response('corrupt') }), /integrity check failed/);
});

test('previous manifests cannot request paths outside deployment artifacts', async (t) => {
  await assert.rejects(optimizeWebBuild({ webBuildDir: fixture(t, 'b'), previousBaseUrl: 'https://app.example',
    fetchImpl: async () => Response.json({ version: 1, files: [{ url: '../secret' }] }) }), /Unsafe asset path/);
});
