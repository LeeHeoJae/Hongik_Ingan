const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const http = require('node:http');
const test = require('node:test');
const handler = require('../api/proxy');
const { requestUpstream, buildUpstreamHeaders } = handler._test;

const target = new URL('http://at.hongik.ac.kr/index.jsp');

async function withUpstream(outcome, run) {
  const original = http.request;
  let attempts = 0;
  http.request = (_url, _options, onResponse) => {
    attempts++;
    const request = new EventEmitter();
    request.setTimeout = () => request;
    request.write = () => {};
    request.end = () => queueMicrotask(() => {
      if (typeof outcome === 'string') {
        request.emit('error', Object.assign(new Error(outcome), { code: outcome }));
        return;
      }
      const response = new EventEmitter();
      response.statusCode = outcome;
      response.headers = { 'retry-after': '20' };
      onResponse(response);
      response.emit('data', Buffer.from('response'));
      response.emit('end');
    });
    return request;
  };
  try {
    await run(() => attempts);
  } finally {
    http.request = original;
  }
}

for (const status of [429, 503]) {
  test(`automatic GET tries once on ${status} and forwards Retry-After`, async () => {
    await withUpstream(status, async (attempts) => {
      const result = await requestUpstream(target,
        { method: 'GET', headers: { 'x-target-retry': 'false' } }, Buffer.alloc(0));
      assert.equal(attempts(), 1);
      assert.equal(result.statusCode, status);
      assert.equal(result.headers['retry-after'], '20');
    });
  });
}

test('ordinary GET keeps its three-attempt policy', async () => {
  await withUpstream(503, async (attempts) => {
    await requestUpstream(target, { method: 'GET', headers: {} }, Buffer.alloc(0));
    assert.equal(attempts(), 3);
  });
});

test('automatic GET does not retry connection errors', async () => {
  await withUpstream('ECONNRESET', async (attempts) => {
    await assert.rejects(requestUpstream(target,
      { method: 'GET', headers: { 'x-target-retry': 'false' } }, Buffer.alloc(0)),
    { code: 'ECONNRESET' });
    assert.equal(attempts(), 1);
  });
});

test('POST retains single-attempt behavior', async () => {
  await withUpstream(503, async (attempts) => {
    await requestUpstream(target, { method: 'POST', headers: {} }, Buffer.alloc(0));
    assert.equal(attempts(), 1);
  });
});

test('request metadata survives inherited IncomingMessage headers', async () => {
  const incoming = Object.create({
    get headers() { return { 'x-target-retry': 'false' }; },
    get method() { return 'GET'; },
  });
  await withUpstream(503, async (attempts) => {
    const result = await requestUpstream(target, incoming, Buffer.alloc(0));
    assert.equal(result.statusCode, 503);
    assert.equal(attempts(), 1);
  });
});

test('proxy-only retry header is not forwarded to the school', () => {
  const headers = buildUpstreamHeaders({ 'x-target-retry': 'false' }, target);
  assert.equal(headers['x-target-retry'], undefined);
});

async function callGuarded(method, headers, url = `/api/proxy?url=${encodeURIComponent(target)}`) {
  const res = {
    headers: {},
    setHeader(name, value) { this.headers[name] = value; },
    getHeader(name) { return this.headers[name]; },
    end(body) { this.body = body?.toString(); },
  };
  const req = Object.assign(new EventEmitter(), { method, url, headers: { host: 'local.invalid', ...headers } });
  const operation = handler(req, res);
  queueMicrotask(() => req.emit('end'));
  await operation;
  return res;
}

for (const [name, method, headers] of [
  ['cross-site fetch', 'GET', { 'sec-fetch-site': 'cross-site', 'sec-fetch-dest': 'empty' }],
  ['direct navigation', 'GET', { 'sec-fetch-site': 'none', 'sec-fetch-dest': 'document' }],
  ['same-origin iframe', 'GET', { 'sec-fetch-site': 'same-origin', 'sec-fetch-dest': 'iframe' }],
  ['CORS preflight', 'OPTIONS', {}],
]) {
  test(`proxy refuses ${name} without CORS headers`, async () => {
    await withUpstream(200, async (attempts) => {
      const res = await callGuarded(method, headers);
      assert.equal(res.statusCode, 403);
      assert.equal(attempts(), 0);
      assert.equal(res.headers['Access-Control-Allow-Origin'], undefined);
      assert.equal(res.headers['Content-Security-Policy'], "sandbox; default-src 'none'");
      assert.equal(res.headers['X-Content-Type-Options'], 'nosniff');
    });
  });
}

test('same-origin fetch is sandboxed and has no CORS headers', async () => {
  await withUpstream(200, async () => {
    const res = await callGuarded('GET', { 'sec-fetch-site': 'same-origin', 'sec-fetch-dest': 'empty' });
    assert.equal(res.statusCode, 200);
    assert.equal(res.body, 'response');
    assert.equal(res.headers['Access-Control-Allow-Origin'], undefined);
    assert.equal(res.headers['Content-Security-Policy'], "sandbox; default-src 'none'");
  });
});

test('proxy rejects non-default ports, other schemes, credentials and bad URLs', async () => {
  for (const url of [
    'https://my.hongik.ac.kr:22/', 'ftp://my.hongik.ac.kr/', 'https://user:pw@my.hongik.ac.kr/',
    'http://203.249.67.222:8080/', 'https://evil.example/',
  ]) {
    assert.equal(handler._test.isAllowedTarget(new URL(url)), false, url);
  }
  assert.equal(handler._test.isAllowedTarget(new URL('http://203.249.67.222/')), true);
  assert.equal((await callGuarded('GET', {}, '/api/proxy?url=not%20a%20url')).statusCode, 400);
  assert.equal((await callGuarded('GET', {}, `/api/proxy?url=${encodeURIComponent('https://my.hongik.ac.kr:22/')}`)).statusCode, 403);
});

test('proxy rejects oversized request bodies before contacting the school', async () => {
  await withUpstream(200, async (attempts) => {
    const res = {
      headers: {},
      setHeader(name, value) { this.headers[name] = value; },
      end(body) { this.body = body?.toString(); },
    };
    const req = Object.assign(new EventEmitter(), {
      method: 'POST', url: `/api/proxy?url=${encodeURIComponent(target)}`, headers: { host: 'local.invalid' },
    });
    const operation = handler(req, res);
    queueMicrotask(() => {
      req.emit('data', Buffer.alloc(64 * 1024 + 1));
      req.emit('end');
    });
    await operation;
    assert.equal(res.statusCode, 413);
    assert.equal(attempts(), 0);
  });
});
