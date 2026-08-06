const BUILD_VERSION = '__HONGIK_INGAN_BUILD_VERSION__';
const APP_SHELL_CACHE = `hongik-ingan-shell-${BUILD_VERSION}`;
const STATIC_CACHE = `hongik-ingan-static-${BUILD_VERSION}`;
const APP_SHELL = [
  '/',
  '/index.html',
  '/manifest.json',
  '/offline.html',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-512.png',
  '/icons/apple-touch-icon.png'
];

const STATIC_FILE_PATTERN =
  /\.(?:js|mjs|wasm|css|png|jpg|jpeg|svg|webp|ico|ttf)$/i;
const REVALIDATED_STATIC_PATHS = new Set([
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
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== APP_SHELL_CACHE && key !== STATIC_CACHE)
          .map((key) => caches.delete(key))
      )
    )
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

  if (STATIC_FILE_PATTERN.test(requestUrl.pathname)) {
    event.respondWith(
      REVALIDATED_STATIC_PATHS.has(requestUrl.pathname)
        ? staleWhileRevalidate(event, request, STATIC_CACHE)
        : cacheFirst(request, STATIC_CACHE)
    );
    return;
  }

  event.respondWith(
    staleWhileRevalidate(event, request, APP_SHELL_CACHE)
  );
});

function shouldNeverCache(url) {
  return NEVER_CACHE_PATHS.some((path) => url.pathname.startsWith(path));
}

async function networkFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  try {
    const response = await fetch(request);
    if (isCacheableResponse(response)) {
      await cache.put(request, response.clone());
    }
    return response;
  } catch (_) {
    return (await cache.match(request)) || Response.error();
  }
}

async function cacheFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cachedResponse = await cache.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }

  try {
    const response = await fetch(request);
    if (isCacheableResponse(response)) {
      await cache.put(request, response.clone());
    }
    return response;
  } catch (_) {
    return Response.error();
  }
}

async function staleWhileRevalidate(event, request, cacheName) {
  const cache = await caches.open(cacheName);
  const cachedResponse = await cache.match(request);
  const networkResponsePromise = fetch(request)
    .then(async (response) => {
      if (isCacheableResponse(response)) {
        await cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => undefined);

  if (cachedResponse) {
    event.waitUntil(networkResponsePromise);
    return cachedResponse;
  }
  return (await networkResponsePromise) || Response.error();
}

function isCacheableResponse(response) {
  return response && response.ok && response.type !== 'opaque';
}
