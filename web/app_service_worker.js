const BUILD_VERSION = '__HONGIK_INGAN_BUILD_VERSION__';
const APP_SHELL_CACHE = `hongik-ingan-shell-${BUILD_VERSION}`;
const STATIC_CACHE = `hongik-ingan-static-${BUILD_VERSION}`;
const IMMUTABLE_CACHE = 'hongik-ingan-immutable-v1';
const HASHED_PATHS = new Set(/*__HONGIK_HASHED_PATHS__*/ []);
const APP_SHELL = [
  '/',
  '/index.html',
  '/manifest.json',
  '/offline.html',
  '/fonts/Pretendard-Bootstrap-Regular.otf',
  '/fonts/Pretendard-Bootstrap-Bold.otf',
  '/assets/assets/images/icon_foreground.png',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-1024.png',
  '/icons/apple-touch-icon.png'
];

const STATIC_FILE_PATTERN =
  /\.(?:js|mjs|wasm|css|png|jpg|jpeg|svg|webp|ico|ttf|otf|woff|woff2)$/i;
const REVALIDATED_STATIC_PATHS = new Set([
  '/keyboard_diagnostics.js',
  '/main.dart.js',
  '/main.dart.mjs',
  '/main.dart.wasm'
]);
const NEVER_CACHE_PATHS = [
  '/api/',
  '/app_service_worker.js',
  '/flutter_service_worker.js',
  '/flutter_bootstrap.js'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(APP_SHELL_CACHE).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    pruneCaches().catch(() => {})
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const requestUrl = new URL(request.url);

  if (requestUrl.origin !== self.location.origin) {
    return;
  }

  if (shouldNeverCache(requestUrl)) {
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => response)
        .catch(() => caches.match('/index.html').then((cachedIndex) => {
          return cachedIndex || caches.match('/offline.html');
        }))
    );
    return;
  }

  if (request.method !== 'GET') {
    return;
  }

  if (isHashedPath(requestUrl.pathname)) {
    event.respondWith(cacheFirst(event, request, IMMUTABLE_CACHE));
    return;
  }

  if (STATIC_FILE_PATTERN.test(requestUrl.pathname)) {
    event.respondWith(
      REVALIDATED_STATIC_PATHS.has(requestUrl.pathname)
        ? networkFirst(event, request, STATIC_CACHE)
        : cacheFirst(event, request,
            APP_SHELL.includes(requestUrl.pathname) ? APP_SHELL_CACHE : STATIC_CACHE)
    );
    return;
  }

  event.respondWith(
    staleWhileRevalidate(event, request, APP_SHELL_CACHE)
  );
});

function isHashedPath(pathname) {
  return /^\/main\.dart\.[a-f0-9]{8}\.(?:js|mjs|wasm)$/.test(pathname) ||
    /^\/assets\/.*\.[a-f0-9]{8}(?:\.[^/]+)?$/.test(pathname);
}

async function pruneCaches() {
  // Keep one previous mutable shell/cache for the first pre-hash transition.
  const keys = await caches.keys();
  for (const prefix of ['hongik-ingan-shell-', 'hongik-ingan-static-']) {
    const old = keys.filter((key) => key.startsWith(prefix) && key !== APP_SHELL_CACHE && key !== STATIC_CACHE);
    await Promise.all(old.slice(0, -1).map((key) => caches.delete(key)));
  }
  const cache = await openCache(IMMUTABLE_CACHE);
  if (cache && HASHED_PATHS.size) {
    const entries = await cache.keys();
    await Promise.all(entries.filter((request) => !HASHED_PATHS.has(new URL(request.url).pathname))
      .map((request) => cache.delete(request)));
  }
}

function shouldNeverCache(url) {
  return NEVER_CACHE_PATHS.some((path) => url.pathname.startsWith(path)) ||
    /^\/manifest(?:-[A-Za-z0-9_-]+)?\.json$/.test(url.pathname) ||
    ['/version.json', '/manifest.json', '/precache_manifest.json', '/web-release-manifest.json'].includes(url.pathname);
}

async function networkFirst(event, request, cacheName) {
  const cache = await openCache(cacheName);
  try {
    const response = await fetch(request);
    // Keep the write alive without delaying delivery of the response body.
    event.waitUntil(cacheResponse(cache, request, response));
    return response;
  } catch (_) {
    return (await readCached(cache, request)) || Response.error();
  }
}

async function cacheFirst(event, request, cacheName) {
  const cache = await openCache(cacheName);
  const cachedResponse = await readCached(cache, request) ||
    (isHashedPath(new URL(request.url).pathname)
      ? await readCached(await openCache(APP_SHELL_CACHE), request) : undefined);
  if (cachedResponse) {
    return cachedResponse;
  }

  try {
    const response = await fetch(request);
    event.waitUntil(cacheResponse(cache, request, response));
    return response;
  } catch (_) {
    return Response.error();
  }
}

async function staleWhileRevalidate(event, request, cacheName) {
  const cache = await openCache(cacheName);
  const cachedResponse = await readCached(cache, request);
  const networkResponsePromise = fetch(request).catch(() => undefined);
  event.waitUntil(
    networkResponsePromise.then((response) =>
      cacheResponse(cache, request, response)
    )
  );

  if (cachedResponse) {
    return cachedResponse;
  }
  return (await networkResponsePromise) || Response.error();
}

// Cache storage is optional; failures must not discard a network response.
async function openCache(cacheName) {
  try {
    return await caches.open(cacheName);
  } catch (_) {
    return null;
  }
}

async function readCached(cache, request) {
  try {
    return await cache?.match(request);
  } catch (_) {
    return undefined;
  }
}

async function cacheResponse(cache, request, response) {
  if (!cache || !isCacheableResponse(response)) return;
  try {
    await cache.put(request, response.clone());
  } catch (_) {
    // A full or unavailable cache does not make the response unusable.
  }
}

function isCacheableResponse(response) {
  return response && response.ok && response.type !== 'opaque' &&
    !(response.headers.get('content-type') || '').includes('text/html');
}
