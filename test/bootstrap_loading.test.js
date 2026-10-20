const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');

const html = fs.readFileSync('web/index.html', 'utf8');
const statusScript = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
  .map((match) => match[1]).find((script) => script.includes('var caption ='));
const loaderScript = fs.readFileSync('web/flutter_bootstrap.js', 'utf8')
  .replace(/{{flutter_(?:js|build_config)}}/g, '');

test('offline retry returns a directly opened fallback to home and preserves original navigation URLs', () => {
  const offlineHtml = fs.readFileSync('web/offline.html', 'utf8');
  const script = offlineHtml.match(/<script>([\s\S]*?)<\/script>/)[1];
  for (const pathname of ['/offline.html', '/', '/attendance']) {
    let click;
    let destination;
    vm.runInNewContext(script, {
      document: { querySelector: () => ({ addEventListener: (_, callback) => { click = callback; } }) },
      window: { location: {
        pathname,
        replace: (url) => { destination = url; },
        reload: () => { destination = 'reload'; },
      } },
    });
    click();
    assert.equal(destination, pathname === '/offline.html' ? '/' : 'reload');
  }
});

function createLoadingScreen() {
  const listeners = new Map();
  const timers = new Map();
  const caption = {
    textContent: 'initial',
    dataset: { stageApp: 'app', stageEngine: 'engine', stageFonts: 'fonts', stageFinish: 'finish', error: 'error' },
  };
  let click;
  let reloads = 0;
  const retry = { hidden: true, addEventListener: (_, callback) => { click = callback; } };
  const bootstrap = {
    dataset: {},
    querySelector: (selector) => selector === '.boot-caption' ? caption : retry,
    remove() {},
  };
  const window = {
    addEventListener(name, callback) {
      if (!listeners.has(name)) listeners.set(name, []);
      listeners.get(name).push(callback);
    },
    setTimeout(callback, delay) { timers.set(callback, delay); return callback; },
    clearTimeout(callback) { timers.delete(callback); },
    location: { reload() { reloads++; } },
  };
  vm.runInNewContext(statusScript, {
    window, navigator: {}, URL,
    document: {
      baseURI: 'https://example.com/',
      getElementById: () => bootstrap,
      body: { classList: { add() {} } },
    },
  });
  return {
    caption, retry, bootstrap,
    emit(name, event = {}) { for (const callback of listeners.get(name) || []) callback(event); },
    retryClick: () => click(),
    reloads: () => reloads,
  };
}

test('loading copy follows actual stage events and ignores unknown stages', () => {
  const screen = createLoadingScreen();
  assert.equal(screen.caption.textContent, 'initial');
  for (const stage of ['engine', 'fonts', 'engine', 'finish']) {
    screen.emit('hongik-bootstrap-stage', { detail: stage });
    assert.equal(screen.caption.textContent, stage);
  }
  screen.emit('hongik-bootstrap-stage', { detail: 'unknown' });
  assert.equal(screen.caption.textContent, 'finish');
  assert.equal(screen.retry.hidden, true);
});

test('startup failure survives later stage events and retry reloads the page', () => {
  const screen = createLoadingScreen();
  screen.emit('hongik-bootstrap-error');
  screen.emit('hongik-bootstrap-stage', { detail: 'fonts' });
  assert.equal(screen.caption.textContent, 'error');
  assert.equal(screen.bootstrap.dataset.state, 'error');
  assert.equal(screen.retry.hidden, false);
  screen.retryClick();
  assert.equal(screen.reloads(), 1);
});

test('only startup script download errors trigger the failure state', () => {
  for (const target of [
    { tagName: 'SCRIPT', id: 'flutter-bootstrap-script', src: 'flutter_bootstrap.js' },
    { tagName: 'SCRIPT', src: 'https://example.com/main.dart.js?v=1' },
  ]) {
    const screen = createLoadingScreen();
    screen.emit('error', { target });
    assert.equal(screen.retry.hidden, false);
  }
  const screen = createLoadingScreen();
  screen.emit('error', { target: { tagName: 'SCRIPT', src: '/_vercel/insights/script.js' } });
  screen.emit('error', { target: { tagName: 'IMG' } });
  assert.equal(screen.retry.hidden, true);
});

test('the first frame ignores later progress and errors', () => {
  const screen = createLoadingScreen();
  screen.emit('flutter-first-frame');
  screen.emit('hongik-bootstrap-stage', { detail: 'engine' });
  screen.emit('hongik-bootstrap-error');
  assert.equal(screen.caption.textContent, 'initial');
  assert.equal(screen.retry.hidden, true);
});

test('loader rejection, engine failure, and runApp failure report startup errors', async () => {
  for (const stage of ['loader', 'engine', 'app', 'success']) {
    const events = [];
    let options;
    vm.runInNewContext(loaderScript, {
      console: { error() {} }, Event,
      CustomEvent: class extends Event { constructor(name, options) { super(name); this.detail = options.detail; } },
      window: { addEventListener() {}, dispatchEvent: (event) => {
        if (event.type === 'hongik-bootstrap-error') events.push(event.type);
      } },
      _flutter: { loader: { load(value) {
        options = value;
        return stage === 'loader' ? Promise.reject(new Error('load')) : Promise.resolve();
      } } },
    });
    if (stage !== 'loader') {
      await options.onEntrypointLoaded({ async initializeEngine() {
        if (stage === 'engine') throw new Error('engine');
        return { async runApp() { if (stage === 'app') throw new Error('app'); } };
      } });
    }
    await new Promise(setImmediate);
    assert.deepEqual(events, stage === 'success' ? [] : ['hongik-bootstrap-error']);
  }
});

function createTrackedLoader({ unsupported = false, observeFails = false } = {}) {
  const stages = [];
  const requests = [];
  let options;
  let observe;
  let firstFrame;
  let disconnected = false;
  const nativeFetch = (...args) => {
    requests.push(args);
    return Promise.resolve({ ok: true });
  };
  const window = {
    fetch: nativeFetch,
    performance: { now: () => 10 },
    PerformanceObserver: unsupported ? undefined : class {
      constructor(callback) { observe = callback; }
      observe() { if (observeFails) throw new Error('Unsupported observer'); }
      disconnect() { disconnected = true; }
    },
    addEventListener: (name, callback) => { if (name === 'flutter-first-frame') firstFrame = callback; },
    dispatchEvent: (event) => { if (event.type === 'hongik-bootstrap-stage') stages.push(event.detail); },
  };
  vm.runInNewContext(loaderScript, {
    window, URL, Event,
    CustomEvent: class extends Event { constructor(name, value) { super(name); this.detail = value.detail; } },
    document: { baseURI: 'https://app.example/' },
    console: { error() {} },
    _flutter: { loader: { load(value) { options = value; return Promise.resolve(); } } },
  });
  return {
    window, nativeFetch, stages, requests,
    enter: (initializer) => options.onEntrypointLoaded(initializer),
    complete(path, startTime = 10) {
      observe({ getEntries: () => [{ name: new URL(path, 'https://app.example/').href, startTime }] });
    },
    firstFrame: () => firstFrame(),
    disconnected: () => disconnected,
  };
}

test('parallel engine/font downloads display remaining work without extra requests', async () => {
  const loader = createTrackedLoader();
  let initialized;
  const pending = loader.enter({ initializeEngine: () => new Promise((resolve) => { initialized = resolve; }) });
  await loader.window.fetch('/assets/assets/fonts/Pretendard-Regular.otf');
  await loader.window.fetch('https://www.gstatic.com/flutter-canvaskit/canvaskit.wasm');
  loader.complete('https://www.gstatic.com/flutter-canvaskit/canvaskit.wasm');
  assert.equal(loader.stages.at(-1), 'fonts');
  loader.complete('/assets/assets/fonts/Pretendard-Regular.otf');
  assert.equal(loader.stages.at(-1), 'engine');
  initialized({ async runApp() {} });
  await pending;
  assert.deepEqual(loader.stages, ['engine', 'fonts', 'engine', 'fonts', 'engine', 'finish']);
  assert.equal(loader.requests.length, 2);
  assert.equal(loader.window.fetch, loader.nativeFetch);
  assert.equal(loader.disconnected(), true);
});

test('pre-entrypoint requests keep the app stage and stale resource entries cannot complete current requests', async () => {
  const loader = createTrackedLoader();
  await loader.window.fetch('/assets/MaterialIcons-Regular.otf');
  assert.deepEqual(loader.stages, []);
  let initialized;
  const pending = loader.enter({ initializeEngine: () => new Promise((resolve) => { initialized = resolve; }) });
  assert.deepEqual(loader.stages, ['fonts']);
  loader.complete('/assets/MaterialIcons-Regular.otf', 0);
  assert.equal(loader.stages.at(-1), 'fonts');
  initialized({ async runApp() {} });
  await pending;
  assert.equal(loader.stages.at(-1), 'finish');
});

test('unrelated requests are passed through and early first-frame cleanup restores native fetch', async () => {
  const loader = createTrackedLoader();
  const input = { url: 'https://app.example/api/attendance' };
  const options = { method: 'POST' };
  await loader.window.fetch(input, options);
  assert.equal(loader.requests[0][0], input);
  assert.equal(loader.requests[0][1], options);
  assert.deepEqual(loader.stages, []);
  loader.firstFrame();
  assert.equal(loader.window.fetch, loader.nativeFetch);
  assert.equal(loader.disconnected(), true);
});

test('unsupported resource observation skips font stages without changing native fetch', async () => {
  for (const settings of [{ unsupported: true }, { observeFails: true }]) {
    const loader = createTrackedLoader(settings);
    assert.equal(loader.window.fetch, loader.nativeFetch);
    await loader.enter({ async initializeEngine() { return { async runApp() {} }; } });
    assert.deepEqual(loader.stages, ['engine', 'finish']);
  }
});

test('initialization failure disconnects observation and restores native fetch', async () => {
  const loader = createTrackedLoader();
  await loader.enter({ async initializeEngine() { throw new Error('engine failed'); } });
  assert.equal(loader.window.fetch, loader.nativeFetch);
  assert.equal(loader.disconnected(), true);
});
