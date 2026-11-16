const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync('web/app_service_worker.js', 'utf8');

function worker({ failure, cached = false, shellCached = false, offline = false, writeBarrier, contentType = 'text/plain', status = 200 } = {}) {
  const listeners = new Map();
  const background = [];
  let fetches = 0;
  let writes = 0;
  const cacheNames = [];
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
      async open(name) {
        cacheNames.push(name);
        fail('open');
        return {
          async match() {
            fail('match');
            return cached || (shellCached && name.startsWith('hongik-ingan-shell-'))
              ? new Response('cached') : undefined;
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
      return new Response('network', { status, headers: { 'content-type': contentType } });
    },
  };
  vm.runInNewContext(source, context);
  return {
    listeners,
    background,
    get fetches() { return fetches; },
    get writes() { return writes; },
    writtenBodies,
    cacheNames,
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

test('offline page fonts and logo are available from the preinstalled app shell', async () => {
  const paths = [
    '/fonts/Pretendard-Bootstrap-Regular.otf',
    '/fonts/Pretendard-Bootstrap-Bold.otf',
    '/assets/assets/images/icon_foreground.png',
  ];
  const listeners = new Map();
  let installed;
  vm.runInNewContext(source, {
    self: { addEventListener: (name, listener) => listeners.set(name, listener), skipWaiting() {} },
    caches: { async open() { return { async addAll(values) { installed = values; } }; } },
  });
  let installation;
  listeners.get('install')({ waitUntil: (task) => { installation = task; } });
  await installation;
  assert.ok(installed.includes('/offline.html'));
  const subject = worker({ shellCached: true, offline: true });
  for (const path of paths) {
    assert.ok(installed.includes(path), path);
    assert.equal(await (await subject.request(path)).text(), 'cached', path);
  }
  assert.equal(subject.fetches, 0);
});

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

test('hashed files reuse a shared cache without a network request', async () => {
  const subject = worker({ cached: true });
  for (const url of ['/main.dart.1234abcd.js', '/main.dart.1234abcd.mjs', '/main.dart.1234abcd.wasm', '/assets/NOTICES.1234abcd', '/assets/font.1234abcd.otf']) {
    assert.equal(await (await subject.request(url)).text(), 'cached');
  }
  assert.equal(subject.fetches, 0);
  assert.ok(subject.cacheNames.every((name) => name === 'hongik-ingan-immutable-v1'));
});

test('preinstalled hashed logo remains available offline', async () => {
  const subject = worker({ shellCached: true, offline: true });
  assert.equal(await (await subject.request('/assets/logo.1234abcd.png')).text(), 'cached');
  assert.equal(subject.fetches, 0);
});

for (const options of [{ contentType: 'text/html' }, { status: 404 }]) {
  test('invalid asset responses are never saved: ' + JSON.stringify(options), async () => {
    const subject = worker(options);
    await subject.request('/main.dart.1234abcd.js');
    await Promise.all(subject.background);
    assert.equal(subject.writes, 0);
  });
}

test('deployment metadata bypasses the service worker cache', () => {
  const subject = worker();
  for (const url of ['/version.json', '/manifest.json', '/precache_manifest.json', '/web-release-manifest.json']) {
    assert.equal(subject.request(url), undefined, url);
  }
});

test('activation retains current and previous hashes and never deletes other apps caches', async () => {
  const paths = ['/assets/shared.1234abcd.otf', '/main.dart.abcdef12.js'];
  const names = ['hongik-ingan-shell-old1', 'hongik-ingan-shell-old2', 'hongik-ingan-shell-current',
    'hongik-ingan-static-old1', 'hongik-ingan-static-old2', 'hongik-ingan-static-current', 'hongik-ingan-immutable-v1', 'other-app'];
  const deletedCaches = [];
  const deletedFiles = [];
  const listeners = new Map();
  vm.runInNewContext(source.replaceAll('__HONGIK_INGAN_BUILD_VERSION__', 'current')
    .replace('/*__HONGIK_HASHED_PATHS__*/ []', JSON.stringify(paths)), {
    URL,
    self: { addEventListener: (name, fn) => listeners.set(name, fn), clients: { claim() {} } },
    caches: {
      async keys() { return names; },
      async delete(name) { deletedCaches.push(name); },
      async open() { return {
        async keys() { return [...paths, '/assets/obsolete.00000000.otf'].map((url) => new Request('https://app.example' + url)); },
        async delete(request) { deletedFiles.push(new URL(request.url).pathname); },
      }; },
    },
  });
  let done;
  listeners.get('activate')({ waitUntil: (task) => { done = task; } });
  await done;
  assert.deepEqual(deletedCaches.sort(), ['hongik-ingan-shell-old1', 'hongik-ingan-static-old1']);
  assert.deepEqual(deletedFiles, ['/assets/obsolete.00000000.otf']);
});
