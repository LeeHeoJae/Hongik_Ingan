{{flutter_js}}
{{flutter_build_config}}

(function () {
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
