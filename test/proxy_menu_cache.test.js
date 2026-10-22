const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const https = require('node:https');
const test = require('node:test');
const handler = require('../api/proxy');
const { PublicResponseCache, classifyPublicCachePolicy, currentKstCacheDay } = require('../server/proxy_cache');

const target = new URL('https://apps.hongik.ac.kr/food/food_m.php?p=1');
const proxyUrl = () => `/api/proxy?url=${encodeURIComponent(target)}&cache-day=${currentKstCacheDay()}`;

function callHandler(accept, refresh = false) {
  const req = Object.assign(new EventEmitter(), {
    method: 'GET',
    url: proxyUrl() + (refresh ? '&cache-bust=1' : ''),
    headers: {
      host: 'local.invalid', accept, 'x-target-retry': 'false',
      ...(refresh ? { pragma: 'no-cache' } : {}),
    },
  });
  const res = {
    headers: {},
    setHeader(name, value) { this.headers[name.toLowerCase()] = value; },
    getHeader(name) { return this.headers[name.toLowerCase()]; },
    end(body) { this.body = body?.toString(); },
  };
  const operation = handler(req, res).then(() => res);
  queueMicrotask(() => req.emit('end'));
  return operation;
}

function mockUpstream(t, outcome) {
  let calls = 0;
  t.mock.method(https, 'request', (_url, _options, callback) => {
    const request = new EventEmitter();
    request.setTimeout = () => request;
    request.write = () => {};
    request.end = () => queueMicrotask(() => {
      calls++;
      const result = outcome();
      if (typeof result === 'string') {
        request.emit('error', Object.assign(new Error(result), { code: result }));
        return;
      }
      const response = Object.assign(new EventEmitter(), {
        statusCode: result.status ?? 200,
        headers: { 'content-type': 'text/html' },
      });
      callback(response);
      response.emit('data', Buffer.from(result.body ?? 'menu'));
      response.emit('end');
    });
    return request;
  });
  return () => calls;
}

for (const instant of ['2026-10-22T00:00:00.000Z', '2026-12-31T14:59:59.500Z']) {
  test(`menu cache expires exactly at KST midnight: ${instant}`, () => {
    const now = new Date(instant);
    const day = currentKstCacheDay(now);
    const url = new URL(`/api/proxy?url=${encodeURIComponent(target)}&cache-day=${day}`, 'https://local.invalid');
    const policy = classifyPublicCachePolicy({ method: 'GET', headers: {} }, target, url, now);
    const expiry = new Date(`${day}T00:00:00+09:00`).getTime() + 86400000;
    assert.equal(policy.expiresAtMs, expiry);
    assert.equal(policy.memoryTtlMs, expiry - now.getTime());
    assert.equal(policy.vercelCacheControl, `public, max-age=${Math.floor((expiry - now.getTime()) / 1000)}`);
    const cache = new PublicResponseCache();
    cache.set('menu', 'saved', policy.memoryTtlMs, now.getTime());
    assert.equal(cache.get('menu', expiry - 1), 'saved');
    assert.equal(cache.get('menu', expiry), null);
    assert.equal(classifyPublicCachePolicy({ method: 'GET', headers: {} }, target, url, new Date(expiry)), null);
  });
}

test('same-day hits outlive old TTLs, CDN TTL shrinks, and a new day fetches again', async (t) => {
  t.mock.timers.enable({ apis: ['Date'], now: new Date('2026-10-22T01:00:00Z') });
  const calls = mockUpstream(t, () => ({}));
  const first = await callHandler(t.name);
  assert.equal(first.headers['vercel-cdn-cache-control'], 'public, max-age=50400');
  t.mock.timers.setTime(new Date('2026-10-22T14:59:59Z').getTime());
  const cached = await callHandler(t.name);
  assert.equal(cached.headers['x-proxy-cache'], 'MEMORY_HIT');
  assert.equal(cached.headers['vercel-cdn-cache-control'], 'public, max-age=1');
  assert.equal(calls(), 1);
  t.mock.timers.setTime(new Date('2026-10-22T15:00:00Z').getTime());
  assert.equal((await callHandler(t.name)).headers['x-proxy-cache'], 'MISS');
  assert.equal(calls(), 2);
});

for (const failure of [500, 503, 504, 'ECONNREFUSED', 'ECONNRESET', 'ETIMEDOUT', 'ENOTFOUND', 'ENETUNREACH', 'EHOSTUNREACH']) {
  test(`manual refresh falls back without replacing cache on ${failure}`, async (t) => {
    let result = { body: 'saved menu' };
    const calls = mockUpstream(t, () => result);
    const original = await callHandler(t.name);
    result = typeof failure === 'number' ? { status: failure, body: 'failure' } : failure;
    const fallback = await callHandler(t.name, true);
    assert.equal(fallback.statusCode, 200);
    assert.equal(fallback.body, 'saved menu');
    assert.equal(fallback.headers['x-proxy-cache'], 'FALLBACK');
    assert.equal(fallback.headers['x-proxy-fetched-at'], original.headers['x-proxy-fetched-at']);
    assert.equal(fallback.headers['cache-control'], 'no-store');
    assert.equal(fallback.headers['vercel-cdn-cache-control'], 'no-store');
    assert.match(fallback.headers['access-control-expose-headers'], /X-Proxy-Cache/);
    assert.equal((await callHandler(t.name)).headers['x-proxy-cache'], 'MEMORY_HIT');
    assert.equal(calls(), 2);
    result = { body: 'updated menu' };
    assert.equal((await callHandler(t.name, true)).body, 'updated menu');
    assert.equal((await callHandler(t.name)).body, 'updated menu');
    assert.equal(calls(), 3);
  });
}

test('failure with no cache stays an error and 4xx does not use a saved menu', async (t) => {
  let result = { status: 503 };
  mockUpstream(t, () => result);
  const failed = await callHandler(t.name);
  assert.equal(failed.statusCode, 503);
  assert.equal(failed.headers['vercel-cdn-cache-control'], 'no-store');
  result = {};
  await callHandler(t.name);
  result = { status: 404 };
  assert.equal((await callHandler(t.name, true)).statusCode, 404);
});

test('a refresh crossing midnight cannot reuse the previous day cache', async (t) => {
  t.mock.timers.enable({ apis: ['Date'], now: new Date('2026-10-22T14:59:59Z') });
  let fail = false;
  mockUpstream(t, () => {
    if (!fail) return {};
    t.mock.timers.setTime(new Date('2026-10-22T15:00:01Z').getTime());
    return { status: 503 };
  });
  await callHandler(t.name);
  fail = true;
  const failed = await callHandler(t.name, true);
  assert.equal(failed.statusCode, 503);
  assert.notEqual(failed.headers['x-proxy-cache'], 'FALLBACK');
});
