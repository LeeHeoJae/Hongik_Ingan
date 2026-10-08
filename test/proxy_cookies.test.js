const test = require('node:test');
const assert = require('node:assert/strict');
const { ProxyCookieJar } = require('../server/proxy_cookies');
const at = new URL('https://at.hongik.ac.kr/index.jsp');
const ap = new URL('https://ap.hongik.ac.kr/check');
const initial = [
  { name: 'JSESSIONID', value: 'at-session', domain: at.hostname, path: '/', hostOnly: true, secure: true },
  { name: 'SSO', value: 'shared', domain: 'hongik.ac.kr', path: '/', hostOnly: false, secure: true },
  { name: 'SSO_AP', value: 'ap-only', domain: ap.hostname, path: '/', hostOnly: true, secure: true },
];
const headers = () => ({ 'x-target-cookie-store': Buffer.from(JSON.stringify(initial)).toString('base64url') });

for (const cookie of ['JSESSIONID=ap-session; Path=/', 'JSESSIONID=ap-session; Path=/check', 'JSESSIONID=; Max-Age=0; Path=/']) {
  test(`ap cookie does not overwrite at session: ${cookie}`, () => {
    const jar = new ProxyCookieJar(at, headers());
    assert.equal(jar.headerFor(ap), 'SSO=shared; SSO_AP=ap-only');
    jar.capture(ap, [cookie]);
    assert.equal(jar.headerFor(at), 'JSESSIONID=at-session; SSO=shared');
  });
}

test('same-host rotation, deletion, path and Secure matching', () => {
  const jar = new ProxyCookieJar(at, headers());
  jar.capture(at, ['JSESSIONID=new; Path=/; Secure', 'JSESSIONID=narrow; Path=/private; Secure']);
  assert.equal(jar.headerFor(at), 'SSO=shared; JSESSIONID=new');
  assert.match(jar.headerFor(new URL('https://at.hongik.ac.kr/private/page')), /^JSESSIONID=narrow;/);
  assert.equal(jar.headerFor(new URL('http://at.hongik.ac.kr/index.jsp')), '');
  jar.capture(at, ['JSESSIONID=; Path=/; Max-Age=0']);
  assert.equal(jar.headerFor(at), 'SSO=shared');
});

test('invalid response domain is ignored, expired cookies are excluded', () => {
  const jar = new ProxyCookieJar(at, headers());
  jar.capture(ap, ['JSESSIONID=bad; Domain=at.hongik.ac.kr; Path=/', 'SSO=expired; Domain=.hongik.ac.kr; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT']);
  assert.equal(jar.headerFor(at), 'JSESSIONID=at-session');
});

test('legacy headers stay on the initial host; request jars are isolated', () => {
  const first = new ProxyCookieJar(at, { 'x-target-cookie': 'JSESSIONID=old' });
  const second = new ProxyCookieJar(at, { 'x-target-cookie': 'JSESSIONID=other' });
  first.capture(at, ['JSESSIONID=new; Path=/']);
  assert.equal(first.headerFor(ap), '');
  assert.equal(second.headerFor(at), 'JSESSIONID=other');
});

test('invalid client scope is rejected', () => {
  assert.throws(() => new ProxyCookieJar(at, { 'x-target-cookie-store': Buffer.from(JSON.stringify([{ ...initial[0], domain: 'example.com' }])).toString('base64url') }));
});

test('proxy preserves scoped cookies through at → ap → at redirects', async (t) => {
  const https = require('node:https');
  const { EventEmitter } = require('node:events');
  const { requestUpstream } = require('../api/proxy')._test;
  const original = https.request;
  t.after(() => { https.request = original; });
  const received = [];
  const responses = [
    { statusCode: 302, headers: { location: ap.href } },
    { statusCode: 302, headers: { location: at.href, 'set-cookie': ['JSESSIONID=ap-session; Path=/; Secure'] } },
    { statusCode: 200, headers: {} },
  ];
  https.request = (url, options, callback) => {
    received.push({ host: url.hostname, cookie: options.headers.cookie });
    const request = new EventEmitter();
    request.setTimeout = () => {};
    request.write = () => {};
    request.end = () => queueMicrotask(() => {
      const response = Object.assign(new EventEmitter(), responses.shift());
      callback(response);
      response.emit('data', Buffer.from('ok'));
      response.emit('end');
    });
    return request;
  };
  const result = await requestUpstream(at, { method: 'POST', headers: headers() }, Buffer.alloc(0));
  assert.equal(result.statusCode, 200);
  assert.deepEqual(received.map((record) => record.cookie), [
    'JSESSIONID=at-session; SSO=shared', 'SSO=shared; SSO_AP=ap-only', 'JSESSIONID=at-session; SSO=shared',
  ]);
  assert.equal(result.targetSetCookies[0].url, ap.href);
});
