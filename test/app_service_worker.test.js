const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync('web/app_service_worker.js', 'utf8');

function worker({ failure, cached = false, offline = false, writeBarrier } = {}) {
  const listeners = new Map();
  const background = [];
  let fetches = 0;
  let writes = 0;
  const writtenBodies = [];
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
          async put(request, response) {
            fail('put');
            writes++;
            await writeBarrier;
            writtenBodies.push(await response.text());
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
    writtenBodies,
    run(strategy) {
      const request = new Request('https://app.example/main.dart.js');
      return context[strategy](
        { waitUntil: (task) => background.push(task) }, request, 'test'
      );
    },
    request(path) {
      let response;
      listeners.get('fetch')({
        request: new Request(`https://app.example${path}`),
        respondWith: (task) => { response = task; },
        waitUntil: (task) => background.push(task),
      });
      return response;
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
      await Promise.all(subject.background);
    });
  }
  test(`${strategy} stores a successful response`, async () => {
    const subject = worker();
    assert.equal(await (await subject.run(strategy)).text(), 'network');
    assert.equal(subject.writes, 1);
    await Promise.all(subject.background);
    assert.deepEqual(subject.writtenBodies, ['network']);
  });
  test(`${strategy} returns a readable response before a slow cache write finishes`, async () => {
    let releaseWrite;
    const writeBarrier = new Promise((resolve) => { releaseWrite = resolve; });
    const subject = worker({ writeBarrier });
    let responseReturned = false;
    const response = subject.run(strategy).then((result) => {
      responseReturned = true;
      return result;
    });
    try {
      await new Promise(setImmediate);
      assert.equal(responseReturned, true);
      assert.equal(subject.background.length, 1);
      assert.equal(await (await response).text(), 'network');
      assert.deepEqual(subject.writtenBodies, []);
    } finally {
      releaseWrite();
    }
    await Promise.all(subject.background);
    assert.deepEqual(subject.writtenBodies, ['network']);
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

for (const extension of ['otf', 'woff', 'woff2']) {
  test(`cached ${extension} fonts are returned without a network request`, async () => {
    const subject = worker({ cached: true });
    const response = await subject.request(`/assets/fonts/Pretendard-Regular.${extension}`);
    assert.equal(await response.text(), 'cached');
    assert.equal(subject.fetches, 0);
    assert.equal(subject.background.length, 0);
  });
}

test('main application files continue to check the network despite a cached copy', async () => {
  const subject = worker({ cached: true });
  for (const path of ['/main.dart.js', '/main.dart.mjs', '/main.dart.wasm', '/keyboard_diagnostics.js']) {
    const response = await subject.request(path);
    assert.equal(await response.text(), 'network');
  }
  await Promise.all(subject.background);
  assert.equal(subject.fetches, 4);
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
