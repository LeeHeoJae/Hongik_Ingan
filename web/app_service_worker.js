const APP_SHELL_CACHE = 'hongik-ingan-shell-v3';
const STATIC_CACHE = 'hongik-ingan-static-v3';
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
  /\.(?:js|mjs|wasm|css|png|jpg|jpeg|svg|webp|ico|woff2|ttf)$/i;
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
    event.respondWith(cacheFirst(request));
    return;
  }

  event.respondWith(
    staleWhileRevalidate(request, APP_SHELL_CACHE)
  );
});

function shouldNeverCache(url) {
  return NEVER_CACHE_PATHS.some((path) => url.pathname.startsWith(path));
}

async function cacheFirst(request) {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }

  const response = await fetch(request);
  if (isCacheableResponse(response)) {
    const cache = await caches.open(STATIC_CACHE);
    await cache.put(request, response.clone());
  }
  return response;
}

async function staleWhileRevalidate(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cachedResponse = await cache.match(request);
  const networkResponsePromise = fetch(request)
    .then((response) => {
      if (isCacheableResponse(response)) {
        cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => undefined);

  if (cachedResponse) {
    return cachedResponse;
  }
  return (await networkResponsePromise) || Response.error();
}

function isCacheableResponse(response) {
  return response && response.ok && response.type !== 'opaque';
}
