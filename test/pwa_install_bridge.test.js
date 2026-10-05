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

test('Windows Firefox에는 버전 판정 없이 주소창 설치를 안내한다', () => {
  for (const version of ['142.0', '143.0', '150.0']) {
    const windowsFirefox = createBrowser({
      userAgent: `Mozilla/5.0 (Windows NT 10.0; Win64; x64) Firefox/${version}`,
      platform: 'Win32',
    });
    assert.equal(targetOf(windowsFirefox), 'windowsFirefoxManual');
  }
});

test('그 밖의 환경에는 설치 미지원 대신 메뉴 확인을 안내한다', () => {
  const macFirefox = createBrowser({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15.0) Firefox/142.0',
    platform: 'MacIntel',
  });

  const linuxFirefox = createBrowser({
    userAgent: 'Mozilla/5.0 (X11; Linux x86_64) Firefox/150.0',
    platform: 'Linux x86_64',
  });
  const unknown = createBrowser({ userAgent: '', platform: '' });
  for (const browser of [macFirefox, linuxFirefox, unknown]) {
    assert.equal(targetOf(browser), 'browserHelp');
  }
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
  assert.equal(targetOf(androidFirefox), 'androidManual');
});

test('iOS Firefox는 공유 메뉴, Android Chromium은 홈 화면 설치를 안내한다', () => {
  const iosFirefox = createBrowser({
    userAgent: 'Mozilla/5.0 (iPhone) AppleWebKit/605.1.15 FxiOS/150.0 Mobile Safari/605.1.15',
    platform: 'iPhone',
  });
  const androidChrome = createBrowser({
    userAgent: 'Mozilla/5.0 (Linux; Android 16) Chrome/140.0 Mobile Safari/537.36',
    platform: 'Linux armv81',
  });
  assert.equal(targetOf(iosFirefox), 'iosManual');
  assert.equal(targetOf(androidChrome), 'androidManual');
});

test('설치 창 호출에 실패해도 해당 환경의 수동 설치 경로를 유지한다', async () => {
  const android = createBrowser({
    userAgent: 'Mozilla/5.0 (Android 16) Chrome/140.0',
    platform: 'Linux armv81',
  });
  android.emit('beforeinstallprompt', {
    preventDefault() {},
    prompt() { throw new Error('unavailable'); },
  });
  assert.equal(targetOf(android), 'nativePrompt');
  assert.equal(await android.bridge.prompt(), 'error');
  assert.equal(targetOf(android), 'androidManual');
});

test('앱으로 실행 중이면 브라우저 안내보다 설치 완료 상태를 우선한다', () => {
  const installed = createBrowser({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0) Firefox/150.0',
    platform: 'Win32',
    standalone: true,
  });
  assert.equal(targetOf(installed), 'installed');
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
