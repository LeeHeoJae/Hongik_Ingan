{{flutter_js}}
{{flutter_build_config}}

(function () {
  // Resolve entrypoints from Flutter's build config, including content hashes.
  var wasmBuild = _flutter.buildConfig.builds.find(function (build) {
    return build.compileTarget === 'dart2wasm';
  });
  var isBlink = navigator.vendor === 'Google Inc.' || navigator.userAgent.indexOf('Edg/') !== -1;
  if (wasmBuild && isBlink && typeof WebAssembly !== 'undefined') {
    var probe = new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 95, 1, 120, 0]);
    var canvas = document.createElement('canvas');
    if (WebAssembly.validate(probe) && (canvas.getContext('webgl2') || canvas.getContext('webgl'))) {
      var preload = document.createElement('link');
      preload.rel = 'preload';
      preload.href = wasmBuild.mainWasmPath;
      preload.as = 'fetch';
      preload.type = 'application/wasm';
      preload.crossOrigin = 'anonymous';
      document.head.appendChild(preload);
      var modulePreload = document.createElement('link');
      modulePreload.rel = 'modulepreload';
      modulePreload.href = wasmBuild.jsSupportRuntimePath;
      modulePreload.crossOrigin = 'anonymous';
      document.head.appendChild(modulePreload);
    }
  }
  var entrypointReady = false;
  var stopped = false;
  var currentStage = 'app';
  var downloads = new Map();
  var originalFetch = window.fetch;
  var observer;
  var trackedFetch;

  function showStage(stage) {
    if (stopped || stage === currentStage) return;
    currentStage = stage;
    window.dispatchEvent(new CustomEvent('hongik-bootstrap-stage', { detail: stage }));
  }

  function updateStage() {
    if (!entrypointReady) return;
    var pending = Array.from(downloads.values());
    showStage(pending.some(function (download) { return download.kind === 'engine'; })
      ? 'engine' : pending.length ? 'fonts' : 'engine');
  }

  function stopTracking() {
    stopped = true;
    if (observer) observer.disconnect();
    if (trackedFetch && window.fetch === trackedFetch) window.fetch = originalFetch;
    downloads.clear();
  }

  // Observe existing requests only; do not fetch or consume any extra font bytes.
  if (window.PerformanceObserver && originalFetch && window.performance) {
    try {
      observer = new window.PerformanceObserver(function (list) {
        list.getEntries().forEach(function (entry) {
          var download = downloads.get(entry.name);
          if (download && entry.startTime >= download.started) downloads.delete(entry.name);
        });
        updateStage();
      });
      observer.observe({ type: 'resource', buffered: true });
      trackedFetch = function (input) {
        var url;
        var kind;
        try {
          url = new URL(typeof input === 'string' ? input : input.url || String(input), document.baseURI);
          if (/\/assets\/.*\.(?:otf|ttf|woff2?)$/i.test(url.pathname)) kind = 'fonts';
          else if (/\/(?:canvaskit|skwasm)[^/]*\.(?:wasm|js)$/.test(url.pathname)) kind = 'engine';
        } catch (_) { /* Leave invalid or unrelated requests to native fetch. */ }
        if (kind) {
          downloads.set(url.href, { kind: kind, started: window.performance.now() });
          updateStage();
        }
        var response = originalFetch.apply(this, arguments);
        if (kind) {
          var finishFailedRequest = function () {
            downloads.delete(url.href);
            updateStage();
          };
          response.then(function (result) {
            if (!result.ok) finishFailedRequest();
          }, finishFailedRequest);
        }
        return response;
      };
      window.fetch = trackedFetch;
    } catch (_) {
      if (observer) observer.disconnect();
    }
  }

  function reportBootstrapError(error) {
    stopTracking();
    console.error('Flutter startup failed', error);
    window.dispatchEvent(new Event('hongik-bootstrap-error'));
  }

  window.addEventListener('flutter-first-frame', stopTracking, { once: true });
  _flutter.loader.load({
    config: {
      wasmAllowList: {
        blink: true,
        gecko: true,
        webkit: true,
      },
    },
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        entrypointReady = true;
        updateStage();
        var appRunner = await engineInitializer.initializeEngine();
        showStage('finish');
        stopTracking();
        await appRunner.runApp();
      } catch (error) {
        reportBootstrapError(error);
      }
    }
  }).catch(reportBootstrapError);
})();
