const http = require('http');
const https = require('https');
const { ProxyCookieJar } = require('./proxy_cookies');

const TARGET_RETRY_REQUEST_HEADER = 'x-target-retry';
const SECOND_MS = 1000;
const UPSTREAM_TIMEOUT_SECONDS = 8;
const PROXY_REQUEST_BUDGET_SECONDS = 9;
const MAX_SAFE_METHOD_ATTEMPTS = 3;
const MIN_RETRY_BUDGET_SECONDS = 1;
const RETRYABLE_STATUS_CODES = new Set([408, 429, 500, 502, 503, 504]);
const RETRYABLE_ERROR_CODES = new Set([
  'ECONNRESET',
  'ETIMEDOUT',
  'EAI_AGAIN',
  'ECONNREFUSED',
  'EPIPE'
]);

const httpAgent = new http.Agent({
  keepAlive: true,
  keepAliveMsecs: 5000,
  maxSockets: 64,
  maxFreeSockets: 16,
  timeout: 10000
});

const httpsAgent = new https.Agent({
  keepAlive: true,
  keepAliveMsecs: 5000,
  maxSockets: 64,
  maxFreeSockets: 16,
  timeout: 10000
});


function createProxyUpstream({ allowedHosts: ALLOWED_HOSTS, buildUpstreamHeaders, safeUrl, shouldFollowRedirects }) {
  async function requestUpstream(
    targetUrl,
    req,
    body,
    redirectCount = 0,
    deadlineMs = Date.now() + PROXY_REQUEST_BUDGET_SECONDS * SECOND_MS,
    targetSetCookies = []
  ) {
    if (!req.targetCookieJar) {
      req = {
        ...req,
        method: req.method,
        headers: req.headers,
        targetCookieJar: new ProxyCookieJar(targetUrl, req.headers)
      };
    }
    const maxAttempts =
      redirectCount === 0 && isRetryableMethod(req.method) && shouldRetry(req.headers)
        ? MAX_SAFE_METHOD_ATTEMPTS
        : 1;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const upstream = await requestUpstreamOnce(
          targetUrl,
          req,
          body,
          redirectCount,
          deadlineMs,
          targetSetCookies
        );

        if (
          attempt < maxAttempts &&
          isRetryableStatus(upstream.statusCode) &&
          hasRetryBudget(deadlineMs)
        ) {
          await waitBeforeRetry(attempt, req.method, targetUrl, upstream.statusCode);
          continue;
        }

        return upstream;
      } catch (error) {
        if (
          attempt >= maxAttempts ||
          !isRetryableError(error) ||
          !hasRetryBudget(deadlineMs)
        ) {
          throw error;
        }

        await waitBeforeRetry(attempt, req.method, targetUrl, error.code || error.message);
      }
    }
  }

  async function requestUpstreamOnce(
    targetUrl,
    req,
    body,
    redirectCount,
    deadlineMs,
    targetSetCookies
  ) {
    const client = targetUrl.protocol === 'http:' ? http : https;
    const agent = targetUrl.protocol === 'http:' ? httpAgent : httpsAgent;
    const headers = buildUpstreamHeaders(req.headers, targetUrl);
    const scopedCookie = req.targetCookieJar.headerFor(targetUrl);
    if (scopedCookie) headers.cookie = scopedCookie;
    const timeoutMs = requestTimeoutMs(deadlineMs);

    const upstream = await new Promise((resolve, reject) => {
      let settled = false;
      let deadlineTimer;
      const finish = (error, result) => {
        if (settled) return;
        settled = true;
        clearTimeout(deadlineTimer);
        if (error) reject(error);
        else resolve(result);
      };
      const interrupted = () => Object.assign(
        new Error('Upstream response ended before the complete body was received.'),
        { code: 'ECONNRESET' }
      );
      const failResponse = (error) => {
        if (settled) return;
        finish(error);
        upstreamReq.destroy(error);
      };
      const upstreamReq = client.request(
        targetUrl,
        {
          method: req.method,
          headers,
          agent
        },
        (upstreamRes) => {
          const chunks = [];
          let ended = false;
          upstreamRes.on('error', failResponse);
          upstreamRes.on('aborted', () => failResponse(interrupted()));
          upstreamRes.on('close', () => {
            if (!ended) failResponse(interrupted());
          });
          upstreamRes.on('data', (chunk) => {
            if (!settled) chunks.push(chunk);
          });
          upstreamRes.on('end', () => {
            ended = true;
            finish(null, {
              statusCode: upstreamRes.statusCode,
              headers: upstreamRes.headers,
              body: Buffer.concat(chunks)
            });
          });
        }
      );

      upstreamReq.on('error', (error) => finish(error));
      const timeout = () => {
        const error = new Error(`Upstream timeout: ${safeUrl(targetUrl)}`);
        error.code = 'ETIMEDOUT';
        failResponse(error);
      };
      // Socket timeouts reset on activity; also bound the total response time.
      deadlineTimer = setTimeout(timeout, timeoutMs);
      upstreamReq.setTimeout(timeoutMs, timeout);
      try {
        if (body.length > 0) upstreamReq.write(body);
        upstreamReq.end();
      } catch (error) {
        failResponse(error);
      }
    });
    collectTargetSetCookies(targetSetCookies, targetUrl, upstream.headers['set-cookie']);
    req.targetCookieJar.capture(targetUrl, upstream.headers['set-cookie']);

    const location = upstream.headers.location;
    if (
      shouldFollowRedirects(req.headers) &&
      isRedirect(upstream.statusCode) &&
      location &&
      redirectCount < 5
    ) {
      const redirectUrl = new URL(Array.isArray(location) ? location[0] : location, targetUrl);
      if (!ALLOWED_HOSTS.has(redirectUrl.hostname)) {
        throw new Error(`Redirect target is not allowed: ${safeUrl(redirectUrl)}`);
      }
      const nextMethod = shouldRewriteRedirectToGet(upstream.statusCode, req.method)
        ? 'GET'
        : req.method;
      const nextReq = {
        ...req,
        method: nextMethod,
        headers: req.headers
      };
      const nextBody = nextMethod === 'GET' || nextMethod === 'HEAD' ? Buffer.alloc(0) : body;
      console.info(
        '[proxy] redirect',
        upstream.statusCode,
        safeUrl(targetUrl),
        '->',
        safeUrl(redirectUrl)
      );
      return requestUpstream(
        redirectUrl,
        nextReq,
        nextBody,
        redirectCount + 1,
        deadlineMs,
        targetSetCookies
      );
    }

    upstream.targetSetCookies = targetSetCookies;
    return upstream;
  }

  function requestTimeoutMs(deadlineMs) {
    const remainingMs = deadlineMs - Date.now() - 250;
    if (remainingMs < MIN_RETRY_BUDGET_SECONDS * SECOND_MS) {
      const error = new Error('Proxy retry budget exhausted before upstream request.');
      error.code = 'ETIMEDOUT';
      throw error;
    }
    return Math.min(UPSTREAM_TIMEOUT_SECONDS * SECOND_MS, remainingMs);
  }

  function isRetryableMethod(method) {
    return method === 'GET' || method === 'HEAD';
  }

  function shouldRetry(headers) {
    return String(headers[TARGET_RETRY_REQUEST_HEADER] || 'true')
      .trim().toLowerCase() !== 'false';
  }

  function isRetryableStatus(statusCode) {
    return RETRYABLE_STATUS_CODES.has(statusCode);
  }

  function isRetryableError(error) {
    return (
      RETRYABLE_ERROR_CODES.has(error.code) ||
      String(error.message || '').includes('Upstream timeout')
    );
  }

  function hasRetryBudget(deadlineMs) {
    return deadlineMs - Date.now() > MIN_RETRY_BUDGET_SECONDS * SECOND_MS;
  }

  async function waitBeforeRetry(attempt, method, targetUrl, reason) {
    const delayMs = retryDelayMs(attempt);
    console.warn(
      '[proxy] retry',
      method,
      safeUrl(targetUrl),
      `attempt=${attempt + 1}`,
      `delay=${delayMs}ms`,
      `reason=${reason}`
    );
    await sleep(delayMs);
  }

  function retryDelayMs(attempt) {
    const baseDelayMs = 180 * 2 ** (attempt - 1);
    const jitterMs = Math.floor(Math.random() * 90);
    return baseDelayMs + jitterMs;
  }

  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  function isRedirect(statusCode) {
    return statusCode >= 300 && statusCode < 400;
  }

  function shouldRewriteRedirectToGet(statusCode, method) {
    return (
      method !== 'GET' &&
      method !== 'HEAD' &&
      (statusCode === 301 || statusCode === 302 || statusCode === 303)
    );
  }

  function collectTargetSetCookies(targetSetCookies, targetUrl, setCookieHeader) {
    const cookies = Array.isArray(setCookieHeader)
      ? setCookieHeader
      : setCookieHeader
        ? [setCookieHeader]
        : [];
    if (cookies.length === 0) {
      return;
    }
    targetSetCookies.push({
      url: targetUrl.toString(),
      cookies: cookies.map(String)
    });
  }

  return { requestUpstream, shouldRetry, isRetryableError, collectTargetSetCookies };
}

module.exports = { createProxyUpstream, SECOND_MS, PROXY_REQUEST_BUDGET_SECONDS };
