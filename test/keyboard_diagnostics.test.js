const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync('web/keyboard_diagnostics.js', 'utf8');

function fixture(search = '?viewportDiagnostics=1') {
  const targets = [];
  function target(fields = {}) {
    const listeners = new Map();
    const result = Object.assign(fields, {
      addEventListener(name, handler) {
        if (!listeners.has(name)) listeners.set(name, new Set());
        listeners.get(name).add(handler);
      },
      removeEventListener(name, handler) { listeners.get(name)?.delete(handler); },
      emit(name) { for (const handler of listeners.get(name) || []) handler(); },
      count() { return [...listeners.values()].reduce((n, set) => n + set.size, 0); },
    });
    targets.push(result);
    return result;
  }
  const timers = new Map();
  const frames = new Map();
  let sequence = 0;
  let downloaded;
  const box = { x: 0, y: 0, width: 1000, height: 800 };
  const element = () => ({ getBoundingClientRect: () => box });
  const input = Object.assign(element(), {
    tagName: 'INPUT', type: 'password',
    getAttribute(name) { assert.equal(name, 'autocomplete'); return 'current-password'; },
  });
  const viewportMeta = { content: 'width=device-width, initial-scale=1.0, maximum-scale=5.0' };
  // Fail if the collector even attempts to access sensitive data.
  for (const name of ['value', 'textContent', 'innerHTML', 'id', 'name', 'selectionStart']) {
    Object.defineProperty(input, name, { get() { throw new Error(`read ${name}`); } });
  }
  const document = target({
    activeElement: input,
    documentElement: { clientWidth: 1000, clientHeight: 800, scrollTop: 0 },
    body: Object.assign(element(), { scrollTop: 0, appendChild() {} }),
    querySelectorAll: () => [element()],
    querySelector(selector) {
      if (selector === 'flutter-view') return element();
      assert.equal(selector, 'meta[flt-viewport]'); return viewportMeta;
    },
    createElement(tag) {
      assert.equal(tag, 'a');
      return { click() {}, remove() {} };
    },
  });
  const viewport = target({ width: 1000, height: 800, offsetTop: 0, offsetLeft: 0, pageTop: 0, pageLeft: 0, scale: 1 });
  const window = target({
    location: { search }, visualViewport: viewport,
    innerWidth: 1000, innerHeight: 800, scrollX: 0, scrollY: 0, devicePixelRatio: 2,
  });
  const navigator = { userAgent: 'test-agent', platform: 'Linux', maxTouchPoints: 10 };
  vm.runInNewContext(source, {
    window, document,
    navigator,
    URLSearchParams, Blob,
    URL: { createObjectURL(blob) { downloaded = blob; return 'blob:test'; }, revokeObjectURL() {} },
    performance: { now: () => sequence++ },
    setTimeout(fn, delay) { const id = ++sequence; timers.set(id, { fn, delay }); return id; },
    clearTimeout(id) { timers.delete(id); },
    requestAnimationFrame(fn) { const id = ++sequence; frames.set(id, fn); return id; },
    cancelAnimationFrame(id) { frames.delete(id); },
  });
  const api = window.hongikKeyboardDiagnostics;
  return {
    api, window, document, viewport, viewportMeta, timers, navigator, viewBox: box,
    count: () => targets.reduce((n, item) => n + item.count(), 0),
    start: (appEnv = 'development') => api.start(JSON.stringify({ appEnv, flutterVersion: 'test-sdk' })),
    flushFrames() { for (const [id, fn] of [...frames]) { frames.delete(id); fn(); } },
    async report() { assert.equal(api.download(), true); return JSON.parse(await downloaded.text()); },
  };
}

test('capture is opt-in and production does not attach listeners', () => {
  for (const search of ['', '?viewportDiagnostics=0', '?other=1']) {
    const env = fixture(search);
    assert.equal(env.start(), false);
    assert.equal(env.count(), 0);
    assert.equal(env.api.download(), false);
  }
  const env = fixture();
  assert.equal(env.start('production'), false);
  assert.equal(env.count(), 0);
});

test('Samsung desktop overlay delivers docked insets and survives capture expiry', async () => {
  const env = fixture('?viewportDiagnostics=1&keyboardViewport=content');
  const listeners = new Map();
  const keyboard = {
    overlaysContent: false,
    boundingRect: { x: 0, y: 800, width: 0, height: 0 },
    addEventListener(name, listener) { listeners.set(name, listener); },
  };
  env.navigator.userAgent = 'SamsungBrowser/30.0';
  env.navigator.virtualKeyboard = keyboard;
  env.api.start(JSON.stringify({ appEnv: 'development', flutterBrowserIsMobile: false }));
  const insets = [];
  assert.equal(env.api.enableDesktopOverlay(height => insets.push(height)), true);
  assert.equal(keyboard.overlaysContent, true);
  keyboard.boundingRect = { x: 0, y: 500, width: 1000, height: 300 };
  listeners.get('geometrychange')();
  assert.deepEqual(insets, [0, 300]);
  // Captured Samsung PC-mode geometry: full width, inconsistent top coordinate.
  Object.assign(env.viewBox, { width: 1204.7059326171875, height: 634.3529663085938 });
  keyboard.boundingRect = { x: 0, y: 31, width: 1204, height: 359 };
  listeners.get('geometrychange')();
  assert.equal(insets.at(-1), 359);
  const report = await env.report();
  assert.equal(report.metadata.desktopOverlayEnabled, true);
  env.api.stop();
  keyboard.boundingRect = { x: 0, y: 0, width: 0, height: 0 };
  listeners.get('geometrychange')();
  assert.equal(insets.at(-1), 0);
  keyboard.boundingRect = { x: 20, y: 200, width: 400, height: 200 };
  listeners.get('geometrychange')();
  assert.equal(insets.at(-1), 0); // floating keyboard
});

test('overlay fallback excludes mobile mode, other browsers and unsupported APIs', () => {
  for (const [mobile, agent, supported] of [
    [true, 'SamsungBrowser/30.0', true],
    [false, 'Chrome/143', true],
    [false, 'SamsungBrowser/30.0', false],
  ]) {
    const env = fixture('?viewportDiagnostics=1&keyboardViewport=content');
    env.navigator.userAgent = agent;
    if (supported) env.navigator.virtualKeyboard = { overlaysContent: false };
    env.api.start(JSON.stringify({ appEnv: 'development', flutterBrowserIsMobile: mobile }));
    assert.equal(env.api.enableDesktopOverlay(() => assert.fail('Unexpected inset')), false);
    if (supported) assert.equal(env.navigator.virtualKeyboard.overlaysContent, false);
  }
});

test('captures viewport movement and paired Flutter metrics without reading credentials', async () => {
  const env = fixture();
  assert.equal(env.start(), true);
  env.api.recordFlutter(JSON.stringify({ reason: 'metrics-frame', views: [{ height: 800, insetBottom: 300 }] }));
  env.viewport.height = 500;
  env.viewport.offsetTop = 50;
  env.document.emit('focusin');
  env.viewport.emit('resize');
  env.flushFrames();
  const report = await env.report();
  const sample = report.events.find(event => event.reason === 'viewport-resize');
  assert.equal(sample.visualViewport.height, 500);
  assert.equal(sample.visualViewport.offsetTop, 50);
  assert.equal(sample.flutter.views[0].insetBottom, 300);
  assert.equal(sample.input.type, 'password');
  assert.equal(sample.input.autocomplete, 'current-password');
  assert.ok(sample.flutter.elapsedMs <= sample.elapsedMs);
  assert.equal(report.metadata.flutterVersion, 'test-sdk');
});

test('bounded retention reports dropped samples', async () => {
  const env = fixture();
  env.start();
  for (let i = 0; i < 450; i++) {
    env.api.recordFlutter(JSON.stringify({ reason: 'metrics', views: [] }));
  }
  const report = await env.report();
  assert.equal(report.events.length, 400);
  assert.ok(report.omitted >= 51);
});

test('expiry removes listeners and timers, keeping the report exportable', async () => {
  const env = fixture();
  env.start();
  env.document.emit('focusin');
  const expiry = [...env.timers.values()].find(timer => timer.delay === 600000);
  expiry.fn();
  assert.equal(env.count(), 0);
  assert.equal(env.timers.size, 0);
  const before = await env.report();
  env.api.recordFlutter(JSON.stringify({ reason: 'late', views: [] }));
  const after = await env.report();
  assert.deepEqual(after.events, before.events);
  assert.equal(after.events.at(-1).reason, 'stop');
});

test('browsers without VisualViewport still record and stop', async () => {
  const env = fixture();
  env.window.visualViewport = null;
  env.start();
  const report = await env.report();
  assert.equal(report.events[0].visualViewport, null);
  env.api.stop();
  assert.equal(env.count(), 0);
});

test('baseline capture preserves the engine viewport policy', async () => {
  const env = fixture();
  const original = env.viewportMeta.content;
  env.start();
  assert.equal(env.viewportMeta.content, original);
  const report = await env.report();
  assert.equal(report.metadata.contentResizeRequested, false);
  assert.equal(report.metadata.viewportContent, original);
});

test('content resize experiment preserves zoom settings and replaces only the keyboard policy', async () => {
  const env = fixture('?viewportDiagnostics=1&keyboardViewport=content');
  env.viewportMeta.content += ', interactive-widget=resizes-visual';
  env.start();
  assert.equal(env.viewportMeta.content,
    'width=device-width, initial-scale=1.0, maximum-scale=5.0, interactive-widget=resizes-content');
  const report = await env.report();
  assert.equal(report.metadata.contentResizeRequested, true);
});

test('production and non-diagnostic pages ignore the content resize experiment', () => {
  for (const [query, appEnv] of [
    ['?keyboardViewport=content', 'development'],
    ['?viewportDiagnostics=1&keyboardViewport=content', 'production'],
  ]) {
    const env = fixture(query);
    const original = env.viewportMeta.content;
    assert.equal(env.start(appEnv), false);
    assert.equal(env.viewportMeta.content, original);
    assert.equal(env.count(), 0);
  }
});
