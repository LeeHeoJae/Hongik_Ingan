const MENU_CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const SEAT_CACHE_TTL_MS = 2 * 1000;
const SEAT_HOSTS = new Set([
  '203.249.67.222',
  '203.249.65.81',
  '223.194.83.66'
]);

class PublicResponseCache {
  constructor(maxEntries = 32) {
    this.maxEntries = maxEntries;
    this.entries = new Map();
  }

  get(key, nowMs = Date.now()) {
    const entry = this.entries.get(key);
    if (!entry) {
      return null;
    }
    if (entry.expiresAtMs <= nowMs) {
      this.entries.delete(key);
      return null;
    }
    return entry.value;
  }

  set(key, value, ttlMs, nowMs = Date.now()) {
    this.deleteExpired(nowMs);
    if (!this.entries.has(key) && this.entries.size >= this.maxEntries) {
      const oldestKey = this.entries.keys().next().value;
      this.entries.delete(oldestKey);
    }
    this.entries.delete(key);
    this.entries.set(key, { value, expiresAtMs: nowMs + ttlMs });
  }

  deleteExpired(nowMs = Date.now()) {
    for (const [key, entry] of this.entries) {
      if (entry.expiresAtMs <= nowMs) {
        this.entries.delete(key);
      }
    }
  }

  clear() {
    this.entries.clear();
  }
}

function currentKstCacheDay(now = new Date()) {
  return new Date(now.getTime() + 9 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}

function classifyPublicCachePolicy(req, targetUrl, proxyRequestUrl, now = new Date()) {
  if (!isPublicCacheRequest(req)) {
    return null;
  }

  if (isMenuTarget(targetUrl)) {
    const cacheDay = proxyRequestUrl.searchParams.get('cache-day');
    if (
      !hasExactQueryParameters(proxyRequestUrl, ['url', 'cache-day']) ||
      cacheDay !== currentKstCacheDay(now)
    ) {
      return null;
    }
    return {
      type: 'menu',
      cacheDay,
      memoryTtlMs: MENU_CACHE_TTL_MS,
      cacheControl: 'public, max-age=0, must-revalidate',
      vercelCacheControl: 'public, max-age=86400'
    };
  }

  if (
    isSeatTarget(targetUrl) &&
    hasExactQueryParameters(proxyRequestUrl, ['url'])
  ) {
    return {
      type: 'seat',
      cacheDay: null,
      memoryTtlMs: SEAT_CACHE_TTL_MS,
      cacheControl: 'public, max-age=0, must-revalidate',
      vercelCacheControl: 'public, max-age=2, stale-while-revalidate=3'
    };
  }

  return null;
}

function isPublicCacheRequest(req) {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return false;
  }
  return !headerValue(req.headers, 'authorization') &&
    !headerValue(req.headers, 'cookie') &&
    !headerValue(req.headers, 'x-target-cookie');
}

function isMenuTarget(targetUrl) {
  if (
    targetUrl.protocol !== 'https:' ||
    targetUrl.hostname !== 'apps.hongik.ac.kr' ||
    targetUrl.pathname !== '/food/food_m.php'
  ) {
    return false;
  }
  if (!hasExactQueryParameters(targetUrl, ['p'])) {
    return false;
  }
  const page = Number(targetUrl.searchParams.get('p'));
  return Number.isInteger(page) && page >= 1 && page <= 5;
}

function isSeatTarget(targetUrl) {
  return targetUrl.protocol === 'http:' &&
    SEAT_HOSTS.has(targetUrl.hostname) &&
    targetUrl.pathname === '/' &&
    [...targetUrl.searchParams.keys()].length === 0;
}

function hasExactQueryParameters(url, expectedNames) {
  const actualNames = [...url.searchParams.keys()].sort();
  const sortedExpectedNames = [...expectedNames].sort();
  return actualNames.length === sortedExpectedNames.length &&
    actualNames.every((name, index) => name === sortedExpectedNames[index]);
}

function headerValue(headers, targetName) {
  for (const [name, value] of Object.entries(headers || {})) {
    if (name.toLowerCase() === targetName) {
      return Array.isArray(value) ? value[0] : value;
    }
  }
  return undefined;
}

function shouldBypassPublicCache(headers) {
  const pragma = String(headerValue(headers, 'pragma') || '').toLowerCase();
  const cacheControl = String(
    headerValue(headers, 'cache-control') || ''
  ).toLowerCase();
  return pragma.split(',').some((part) => part.trim() === 'no-cache') ||
    cacheControl.split(',').some((part) => {
      const directive = part.trim();
      return directive === 'no-cache' || directive === 'no-store';
    });
}

function isCacheablePublicResponse(policy, upstream) {
  return policy !== null &&
    upstream.statusCode === 200 &&
    Buffer.isBuffer(upstream.body) &&
    upstream.body.length > 0 &&
    Array.isArray(upstream.targetSetCookies) &&
    upstream.targetSetCookies.length === 0 &&
    !upstream.headers['set-cookie'] &&
    !upstream.headers.location;
}

function publicCacheKey(policy, targetUrl, requestHeaders, acceptEncoding) {
  return [
    policy.type,
    policy.cacheDay || '-',
    targetUrl.toString(),
    String(headerValue(requestHeaders, 'accept') || ''),
    acceptEncoding
  ].join('|');
}

module.exports = {
  PublicResponseCache,
  classifyPublicCachePolicy,
  currentKstCacheDay,
  isCacheablePublicResponse,
  publicCacheKey,
  shouldBypassPublicCache
};
