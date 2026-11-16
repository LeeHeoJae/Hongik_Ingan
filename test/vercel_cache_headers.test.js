const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const config = JSON.parse(fs.readFileSync('vercel.json', 'utf8'));

// Model ordered matching rules; deployed response headers still need verification.
function cacheControl(pathname) {
  let value;
  for (const rule of config.headers) {
    if (!new RegExp(`^(?:${rule.source})$`).test(pathname)) continue;
    for (const header of rule.headers) {
      if (header.key.toLowerCase() === 'cache-control') value = header.value;
    }
  }
  return value;
}

test('entry points and update metadata retain no-store after every matching rule', () => {
  for (const pathname of [
    '/index.html',
    '/offline.html',
    '/app_service_worker.js',
    '/flutter_service_worker.js',
    '/flutter_bootstrap.js',
    '/version.json',
    '/manifest.json',
    '/precache_manifest.json',
    '/web-release-manifest.json',
  ]) {
    assert.equal(cacheControl(pathname), 'no-store', pathname);
  }
});

test('only content-addressed application resources get immutable browser caching', () => {
  for (const url of ['/main.dart.1234abcd.js', '/main.dart.1234abcd.mjs', '/main.dart.1234abcd.wasm',
    '/assets/assets/fonts/Pretendard-Regular.1234abcd.otf', '/assets/NOTICES.1234abcd']) {
    assert.equal(cacheControl(url), 'public, max-age=31536000, immutable', url);
  }
  for (const url of ['/flutter_bootstrap.js', '/manifest.json', '/assets/fonts/font.otf', '/canvaskit/canvaskit.wasm']) {
    assert.ok(!cacheControl(url)?.includes('immutable'), url);
  }
});

test('SPA rewrite excludes missing static resources and API paths', () => {
  const rule = config.rewrites.find((entry) => entry.destination === '/index.html');
  const matches = new RegExp('^/' + rule.source.slice('/:path'.length) + '$');
  for (const url of ['/assets/NOTICES.1234abcd', '/main.dart.1234abcd.js', '/fonts/missing.otf', '/api/proxy', '/manifest.json', '/icons/missing.png', '/canvaskit/missing.wasm']) {
    assert.equal(matches.test(url), false, url);
  }
  for (const url of ['/', '/attendance/history', '/apiary']) assert.equal(matches.test(url), true, url);
});

test('unversioned application files and web fonts revalidate their HTTP cache', () => {
  for (const pathname of [
    '/main.dart.js',
    '/main.dart.mjs',
    '/main.dart.wasm',
    '/keyboard_diagnostics.js',
    '/assets/assets/fonts/Pretendard-Regular.otf',
    '/assets/fonts/example.woff',
    '/assets/fonts/example.woff2',
  ]) {
    assert.equal(cacheControl(pathname), 'public, max-age=0, must-revalidate', pathname);
  }
});

test('engine resources keep their policy and unhashed icons revalidate', () => {
  assert.equal(
    cacheControl('/canvaskit/canvaskit.wasm'),
    'public, max-age=0, s-maxage=604800, stale-while-revalidate=86400'
  );
  assert.equal(
    cacheControl('/icons/Icon-192.png'),
    'public, max-age=0, must-revalidate'
  );
});
