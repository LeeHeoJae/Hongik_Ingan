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
    '/app_service_worker.js',
    '/flutter_service_worker.js',
    '/flutter_bootstrap.js',
    '/version.json',
    '/manifest.json',
  ]) {
    assert.equal(cacheControl(pathname), 'no-store', pathname);
  }
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

test('other static assets keep their existing shared and browser caching policies', () => {
  assert.equal(
    cacheControl('/canvaskit/canvaskit.wasm'),
    'public, max-age=0, s-maxage=604800, stale-while-revalidate=86400'
  );
  assert.equal(
    cacheControl('/icons/Icon-192.png'),
    'public, max-age=604800, s-maxage=2592000, stale-while-revalidate=604800'
  );
});
