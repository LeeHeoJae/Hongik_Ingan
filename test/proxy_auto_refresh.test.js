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

test('proxy-only retry header is not forwarded to the school', () => {
  const headers = buildUpstreamHeaders({ 'x-target-retry': 'false' }, target);
  assert.equal(headers['x-target-retry'], undefined);
});

test('CORS exposes Retry-After and accepts the retry option', async () => {
  const headers = {};
  await handler({ method: 'OPTIONS' }, {
    setHeader: (name, value) => { headers[name] = value; }, end: () => {},
  });
  assert.match(headers['Access-Control-Allow-Headers'], /X-Target-Retry/);
  assert.match(headers['Access-Control-Expose-Headers'], /Retry-After/);
});
