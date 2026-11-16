const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');

const html = fs.readFileSync('web/index.html', 'utf8');
const resetScript = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
  .map((match) => match[1]).find((script) => script.includes('viewport.offsetTop'));

const iphone = 'Mozilla/5.0 (iPhone) AppleWebKit/605.1.15 Version/26.0 Mobile Safari/604.1';

function createScreen({ userAgent = iphone, platform = 'iPhone', viewport = {} } = {}) {
  let focusout;
  let pending;
  const scrolls = [];
  const document = {
    activeElement: { tagName: 'BODY' },
    addEventListener(type, listener) {
      if (type === 'focusout') focusout = listener;
    },
  };
  const window = {
    scrollX: 0,
    scrollY: 0,
    visualViewport: { scale: 1, offsetTop: 0, offsetLeft: 0, ...viewport },
    scrollTo(x, y) {
      scrolls.push([x, y]);
    },
  };
  vm.runInNewContext(resetScript, {
    document,
    window,
    navigator: { userAgent, platform, maxTouchPoints: 5 },
    setTimeout(callback) {
      pending = callback;
      return 1;
    },
    clearTimeout() {
      pending = undefined;
    },
  });
  return {
    document,
    window,
    scrolls,
    listening: Boolean(focusout),
    blurAndSettle() {
      focusout();
      pending?.();
    },
  };
}

test('iOS에서 키보드가 닫힌 뒤 남은 화면 오프셋을 되돌린다', () => {
  const screen = createScreen({ viewport: { offsetTop: 24 } });
  screen.blurAndSettle();
  assert.deepEqual(screen.scrolls, [[0, 0]]);

  const scrolled = createScreen();
  scrolled.window.scrollY = 29;
  scrolled.blurAndSettle();
  assert.deepEqual(scrolled.scrolls, [[0, 0]]);
});

test('오프셋이 없거나 다른 입력창으로 포커스가 옮겨 가면 그대로 둔다', () => {
  const clean = createScreen();
  clean.blurAndSettle();
  assert.deepEqual(clean.scrolls, []);

  const nextField = createScreen({ viewport: { offsetTop: 24 } });
  nextField.document.activeElement = { tagName: 'INPUT' };
  nextField.blurAndSettle();
  assert.deepEqual(nextField.scrolls, []);
});

test('사용자가 확대한 화면은 그대로 둔다', () => {
  const zoomed = createScreen({ viewport: { scale: 2, offsetTop: 120 } });
  zoomed.blurAndSettle();
  assert.deepEqual(zoomed.scrolls, []);
});

test('iOS가 아닌 환경에서는 동작하지 않는다', () => {
  const android = createScreen({
    userAgent: 'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/140.0 Mobile Safari/537.36',
    platform: 'Linux armv8l',
  });
  assert.equal(android.listening, false);
});
