// Opt-in measurements; an explicit development-only query enables the viewport
// policy experiment. Never read input values or include page URLs in reports.
window.hongikKeyboardDiagnostics = (() => {
  const capacity = 400;
  let metadata;
  let active = false;
  let events = [];
  let omitted = 0;
  let flutter = null;
  let startedAt = 0;
  let pendingFrame = null;
  let expiry = null;
  const listeners = [];
  const settleTimers = new Set();
  let overlayListening = false;

  function rect(element) {
    if (!element) return null;
    const box = element.getBoundingClientRect();
    return { x: box.x, y: box.y, width: box.width, height: box.height };
  }

  function capture(reason) {
    if (!active) return;
    const viewport = window.visualViewport;
    const input = document.activeElement;
    const editable = input && /^(INPUT|TEXTAREA)$/.test(input.tagName);
    const hint = editable ? input.getAttribute('autocomplete') : null;
    events.push({
      elapsedMs: Math.round(performance.now() - startedAt),
      reason,
      window: {
        width: window.innerWidth, height: window.innerHeight,
        scrollX: window.scrollX, scrollY: window.scrollY,
        devicePixelRatio: window.devicePixelRatio,
      },
      visualViewport: viewport ? {
        width: viewport.width, height: viewport.height,
        offsetTop: viewport.offsetTop, offsetLeft: viewport.offsetLeft,
        pageTop: viewport.pageTop, pageLeft: viewport.pageLeft,
        scale: viewport.scale,
      } : null,
      virtualKeyboard: navigator.virtualKeyboard ? {
        overlaysContent: navigator.virtualKeyboard.overlaysContent,
        rect: keyboardRect(),
      } : null,
      document: {
        width: document.documentElement.clientWidth,
        height: document.documentElement.clientHeight,
        scrollTop: document.documentElement.scrollTop,
        bodyScrollTop: document.body?.scrollTop ?? 0,
        bodyRect: rect(document.body),
      },
      flutterViews: Array.from(document.querySelectorAll('flutter-view'))
        .slice(0, 4).map(rect),
      input: editable ? {
        type: ['text', 'password', 'number', 'tel', 'email'].includes(input.type)
          ? input.type : 'other',
        autocomplete: ['username', 'current-password', 'one-time-code'].includes(hint)
          ? hint : 'other',
        rect: rect(input),
      } : null,
      // This is the latest engine/frame sample, not necessarily this DOM frame.
      flutter,
    });
    if (events.length > capacity) {
      events.shift();
      omitted++;
    }
  }

  function schedule(reason) {
    if (pendingFrame !== null) return;
    pendingFrame = requestAnimationFrame(() => {
      pendingFrame = null;
      capture(reason);
    });
  }

  function focusChanged() {
    capture('dom-focus');
    for (const timer of settleTimers) clearTimeout(timer);
    settleTimers.clear();
    for (const delay of [100, 400, 800]) {
      const timer = setTimeout(() => {
        settleTimers.delete(timer);
        capture(`focus-settled-${delay}`);
      }, delay);
      settleTimers.add(timer);
    }
  }

  function listen(target, name, callback) {
    if (!target) return;
    target.addEventListener(name, callback, { passive: true });
    listeners.push(() => target.removeEventListener(name, callback));
  }

  function stop() {
    if (!active) return;
    capture('stop');
    active = false;
    listeners.splice(0).forEach(remove => remove());
    for (const timer of settleTimers) clearTimeout(timer);
    settleTimers.clear();
    clearTimeout(expiry);
    if (pendingFrame !== null) cancelAnimationFrame(pendingFrame);
    pendingFrame = null;
  }

  function start(metadataJson) {
    if (active) return true;
    const info = JSON.parse(metadataJson);
    const query = new URLSearchParams(window.location.search);
    if (info.appEnv !== 'development' ||
        query.get('viewportDiagnostics') !== '1') {
      return false;
    }
    // Flutter replaces the HTML viewport meta during engine initialization.
    // start() is invoked by Dart after that initialization, before runApp().
    // Resizing the layout viewport as well as the visual viewport aims to avoid
    // the extra visual-viewport panning seen in Samsung Internet device traces.
    // Keep this opt-in until the affected tablet confirms the result.
    const viewportMeta = document.querySelector('meta[flt-viewport]');
    const contentResizeRequested = query.get('keyboardViewport') === 'content';
    if (contentResizeRequested && viewportMeta) {
      const directives = viewportMeta.content.split(',')
        .map(value => value.trim())
        .filter(value => value && !/^interactive-widget\s*=/i.test(value));
      viewportMeta.content = [...directives, 'interactive-widget=resizes-content'].join(', ');
    }
    metadata = {
      ...info,
      contentResizeRequested,
      desktopOverlayEnabled: false,
      viewportContent: viewportMeta?.content ?? null,
      userAgent: navigator.userAgent,
      platform: navigator.platform,
      maxTouchPoints: navigator.maxTouchPoints,
      startedAt: new Date().toISOString(),
    };
    events = [];
    omitted = 0;
    flutter = null;
    active = true;
    startedAt = performance.now();
    listen(document, 'focusin', focusChanged);
    listen(document, 'focusout', focusChanged);
    for (const name of ['resize', 'scroll', 'orientationchange']) {
      listen(window, name, () => schedule(`window-${name}`));
    }
    for (const name of ['resize', 'scroll']) {
      listen(window.visualViewport, name, () => schedule(`viewport-${name}`));
    }
    expiry = setTimeout(stop, 10 * 60 * 1000);
    capture('start');
    return true;
  }

  function recordFlutter(snapshotJson) {
    if (!active) return;
    flutter = { ...JSON.parse(snapshotJson), elapsedMs: Math.round(performance.now() - startedAt) };
    capture(`flutter-${flutter.reason}`);
  }

  function keyboardRect() {
    const box = navigator.virtualKeyboard?.boundingRect;
    return box ? { x: box.x, y: box.y, width: box.width, height: box.height } : null;
  }

  function enableDesktopOverlay(onInset) {
    const keyboard = navigator.virtualKeyboard;
    if (!active || !metadata.contentResizeRequested ||
        metadata.flutterBrowserIsMobile !== false ||
        !/SamsungBrowser\//.test(navigator.userAgent) ||
        !(navigator.maxTouchPoints > 0) || !keyboard) return false;
    if (overlayListening) return true;
    const update = () => {
      const box = keyboard.boundingRect;
      const view = document.querySelector('flutter-view');
      const bounds = view?.getBoundingClientRect();
      const left = bounds?.x ?? 0;
      const width = bounds?.width ?? window.innerWidth;
      const viewHeight = bounds?.height ?? window.innerHeight;
      const bottom = bounds ? bounds.y + bounds.height : window.innerHeight;
      const visible = box && box.height > 0 && box.width > 0;
      const docked = visible &&
        box.y + box.height >= bottom - 1;
      // Samsung PC mode can report a full-width keyboard at y=31 even though
      // it occupies the bottom of a 634px view. Its height remains usable. This
      // fallback is scoped to Samsung desktop mode by the guards above.
      const fullWidth = visible && box.x <= left + 1 &&
        box.x + box.width >= left + width - 1;
      const rawHeight = docked ? bottom - box.y : (fullWidth ? box.height : 0);
      const height = Math.max(0, Math.min(viewHeight, rawHeight));
      onInset(height);
      capture('virtual-keyboard');
    };
    try {
      keyboard.overlaysContent = true;
      if (!keyboard.overlaysContent) return false;
      // This listener owns layout for the document lifetime. Do not remove it
      // when diagnostic capture expires, leaving an overlay without insets.
      keyboard.addEventListener('geometrychange', update);
      overlayListening = true;
      metadata.desktopOverlayEnabled = true;
      update();
      return true;
    } catch (_) {
      return false;
    }
  }

  function download() {
    if (!metadata) return false;
    capture('download');
    const blob = new Blob([JSON.stringify({ schemaVersion: 1, metadata, omitted, events }, null, 2)],
      { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = 'hongik-keyboard-diagnostics.json';
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    return true;
  }

  return Object.freeze({ start, recordFlutter, download, enableDesktopOverlay, stop });
})();
