const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');
const vm = require('node:vm');

const indexHtml = fs.readFileSync('web/index.html', 'utf8');
const bridgeStart = indexHtml.indexOf('window.hongikPwaInstall =');
const scriptStart = indexHtml.lastIndexOf('<script>', bridgeStart) + '<script>'.length;
const scriptEnd = indexHtml.indexOf('</script>', bridgeStart);
const bridgeScript = indexHtml.slice(scriptStart, scriptEnd);

function createBrowser({ userAgent, platform, standalone = false }) {
  const eventListeners = new Map();
  const mediaListeners = new Map();
  const navigator = {
    userAgent,
    platform,
    maxTouchPoints: 0,
    standalone,
  };
  const mediaQuery = {
    matches: false,
    addEventListener(type, listener) {
      mediaListeners.set(type, listener);
    },
  };
  const window = {
    navigator,
    matchMedia() {
      return mediaQuery;
    },
    addEventListener(type, listener) {
      eventListeners.set(type, listener);
    },
  };

  vm.runInNewContext(bridgeScript, {
    JSON,
    Promise,
    Set,
    navigator,
    window,
  });

  return {
    bridge: window.hongikPwaInstall,
    emit(type, event = {}) {
      eventListeners.get(type)?.(event);
    },
  };
}

function targetOf(browser) {
  return JSON.parse(browser.bridge.getStateJson()).target;
}

test('Apple 환경을 수동 설치 대상으로 구분한다', () => {
  const iphone = createBrowser({
    userAgent: 'Mozilla/5.0 (iPhone) AppleWebKit/605.1.15 Version/26.0 Mobile Safari/604.1',
    platform: 'iPhone',
  });
  const macSafari = createBrowser({
    userAgent: 'Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 Version/26.0 Safari/605.1.15',
    platform: 'MacIntel',
  });

  assert.equal(targetOf(iphone), 'iosManual');
  assert.equal(targetOf(macSafari), 'macSafariManual');
});

test('데스크톱 Firefox에는 지원 브라우저 안내를 제공한다', () => {
  const windowsFirefox = createBrowser({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Firefox/142.0',
    platform: 'Win32',
  });
  const macFirefox = createBrowser({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15.0) Firefox/142.0',
    platform: 'MacIntel',
  });

  assert.equal(targetOf(windowsFirefox), 'unsupportedBrowser');
  assert.equal(targetOf(macFirefox), 'unsupportedBrowser');
});

test('Linux Chromium과 Android Firefox에는 브라우저 메뉴 설치를 안내한다', () => {
  const linuxChrome = createBrowser({
    userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/140.0 Safari/537.36',
    platform: 'Linux x86_64',
  });
  const androidFirefox = createBrowser({
    userAgent: 'Mozilla/5.0 (Android 16; Mobile; rv:142.0) Gecko/142.0 Firefox/142.0',
    platform: 'Linux armv81',
  });

  assert.equal(targetOf(linuxChrome), 'browserManual');
  assert.equal(targetOf(androidFirefox), 'browserManual');
});

test('Chromium 설치 이벤트를 한 번 사용하고 완료 상태를 알린다', async () => {
  const chrome = createBrowser({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/140.0 Safari/537.36',
    platform: 'Win32',
  });
  let promptCount = 0;
  let prevented = false;
  const states = [];
  chrome.bridge.subscribe((state) => states.push(JSON.parse(state).target));

  chrome.emit('beforeinstallprompt', {
    preventDefault() {
      prevented = true;
    },
    prompt() {
      promptCount++;
    },
    userChoice: Promise.resolve({ outcome: 'accepted' }),
  });

  assert.equal(prevented, true);
  assert.equal(targetOf(chrome), 'nativePrompt');
  assert.equal(await chrome.bridge.prompt(), 'accepted');
  assert.equal(promptCount, 1);
  assert.equal(await chrome.bridge.prompt(), 'unavailable');

  chrome.emit('appinstalled');
  assert.equal(targetOf(chrome), 'installed');
  assert.deepEqual(states, ['nativePrompt', 'browserManual', 'installed']);
});
