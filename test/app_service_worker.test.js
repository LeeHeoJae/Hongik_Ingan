const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync('web/app_service_worker.js', 'utf8');

function worker({ failure, cached = false, offline = false } = {}) {
  const listeners = new Map();
  const background = [];
  let fetches = 0;
  let writes = 0;
  const fail = (operation) => {
    if (failure === operation) throw new Error('Cache unavailable');
  };
  const context = {
    URL,
    Response,
    self: {
      location: { origin: 'https://app.example' },
      addEventListener: (type, listener) => listeners.set(type, listener),
    },
    caches: {
      async open() {
        fail('open');
        return {
          async match() {
            fail('match');
            return cached ? new Response('cached') : undefined;
          },
          async put() {
            fail('put');
            writes++;
          },
        };
      },
    },
    async fetch() {
      fetches++;
      if (offline) throw new Error('Offline');
      return new Response('network');
    },
  };
  vm.runInNewContext(source, context);
  return {
    listeners,
    background,
    get fetches() { return fetches; },
    get writes() { return writes; },
    run(strategy) {
      const request = new Request('https://app.example/main.dart.js');
      return strategy === 'staleWhileRevalidate'
        ? context[strategy]({ waitUntil: (task) => background.push(task) }, request, 'test')
        : context[strategy](request, 'test');
    },
  };
}

for (const strategy of ['networkFirst', 'cacheFirst', 'staleWhileRevalidate']) {
  for (const failure of ['open', 'match', 'put']) {
    if (strategy === 'networkFirst' && failure === 'match') continue;
    test(`${strategy} preserves the network response when cache ${failure} fails`, async () => {
      const subject = worker({ failure });
      assert.equal(await (await subject.run(strategy)).text(), 'network');
      assert.equal(subject.fetches, 1);
    });
  }
  test(`${strategy} stores a successful response`, async () => {
    const subject = worker();
    assert.equal(await (await subject.run(strategy)).text(), 'network');
    assert.equal(subject.writes, 1);
  });
  test(`${strategy} returns an error response when offline without a cache`, async () => {
    assert.equal((await worker({ offline: true }).run(strategy)).type, 'error');
  });
}

test('network first falls back to cached content when offline', async () => {
  const subject = worker({ cached: true, offline: true });
  assert.equal(await (await subject.run('networkFirst')).text(), 'cached');
});

test('network first returns an error response when offline and cache reading fails', async () => {
  const subject = worker({ cached: true, offline: true, failure: 'match' });
  assert.equal((await subject.run('networkFirst')).type, 'error');
});

test('cache first skips the network on a cache hit', async () => {
  const subject = worker({ cached: true });
  assert.equal(await (await subject.run('cacheFirst')).text(), 'cached');
  assert.equal(subject.fetches, 0);
});

test('stale content is returned while its refresh is kept alive', async () => {
  const subject = worker({ cached: true, failure: 'put' });
  assert.equal(await (await subject.run('staleWhileRevalidate')).text(), 'cached');
  assert.equal(subject.background.length, 1);
  await Promise.all(subject.background);
  assert.equal(subject.fetches, 1);
});

test('school API and worker bootstrap requests still bypass caching', () => {
  const subject = worker();
  for (const path of ['/api/proxy', '/app_service_worker.js', '/flutter_service_worker.js', '/flutter_bootstrap.js']) {
    subject.listeners.get('fetch')({
      request: new Request(`https://app.example${path}`),
      respondWith() { assert.fail(`Unexpected interception: ${path}`); },
    });
  }
  assert.equal(subject.fetches, 0);
});
