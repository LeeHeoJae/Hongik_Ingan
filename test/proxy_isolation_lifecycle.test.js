const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const http = require('node:http');
const https = require('node:https');
const test = require('node:test');
const handler = require('../api/proxy');
const { currentKstCacheDay, classifyPublicCachePolicy } = require('../server/proxy_cache');

const menu = new URL('https://apps.hongik.ac.kr/food/food_m.php?p=5');
const proxyUrl = `/api/proxy?url=${encodeURIComponent(menu)}&cache-day=${currentKstCacheDay()}`;
const cookieStore = (value) => Buffer.from(JSON.stringify([{
  name: 'SESSION', value, domain: 'hongik.ac.kr', hostOnly: false,
  path: '/', secure: true, expiresAt: null,
}])).toString('base64url');

function mockUpstream(t, client, respond) {
  let attempts = 0;
  t.mock.method(client, 'request', (url, options, callback) => {
    const request = new EventEmitter();
    request.setTimeout = () => request;
    request.write = () => {};
    request.destroy = (error) => {
      request.destroyed = true;
      if (error) queueMicrotask(() => request.emit('error', error));
    };
    request.end = () => {
      attempts++;
      queueMicrotask(() => {
        const response = new EventEmitter();
        response.statusCode = 200;
        response.headers = { 'content-type': 'text/plain' };
        callback(response);
        respond(response, options, request, url);
      });
    };
    return request;
  });
  return () => attempts;
}

function callHandler(headers = {}) {
  const req = new EventEmitter();
  req.method = 'GET';
  req.url = proxyUrl;
  req.headers = { host: 'local.invalid', ...headers };
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

test('cookie-store header presence excludes public caching, including empty stores', () => {
  for (const value of ['', 'W10=', cookieStore('synthetic')]) {
    assert.equal(classifyPublicCachePolicy({ method: 'GET', headers: {
      'X-Target-Cookie-Store': value,
    } }, menu, new URL(proxyUrl, 'https://local.invalid')), null);
  }
});

test('authenticated requests neither hit, populate, nor coalesce public cache', async (t) => {
  const pending = [];
  const attempts = mockUpstream(t, https, (response, options) => {
    pending.push(() => {
      response.emit('data', Buffer.from(options.headers.cookie || 'anonymous'));
      response.emit('end');
      response.emit('close');
    });
  });
  async function complete(operations, expectedRequests) {
    await new Promise(setImmediate);
    assert.equal(pending.length, expectedRequests);
    pending.splice(0).forEach((send) => send());
    return Promise.all(operations);
  }
  const a = { 'x-target-cookie-store': cookieStore('user-a') };
  const b = { 'x-target-cookie-store': cookieStore('user-b') };
  const responses = await complete([callHandler(a), callHandler(a), callHandler(b)], 3);
  assert.deepEqual(responses.map((res) => res.body), ['SESSION=user-a', 'SESSION=user-a', 'SESSION=user-b']);
  for (const res of responses) {
    assert.equal(res.headers['cache-control'], 'no-store');
    assert.equal(res.headers['vercel-cdn-cache-control'], 'no-store');
    assert.equal(res.headers['x-proxy-cache'], 'BYPASS');
  }
  const [anonymous] = await complete([callHandler()], 1);
  assert.equal(anonymous.body, 'anonymous');
  assert.equal((await callHandler()).headers['x-proxy-cache'], 'MEMORY_HIT');
  const [authenticatedAfterWarmup] = await complete([callHandler(a)], 1);
  assert.equal(authenticatedAfterWarmup.body, 'SESSION=user-a');
  assert.equal(attempts(), 5);
});
