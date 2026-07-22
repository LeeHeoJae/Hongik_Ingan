const http = require('http');
const https = require('https');

const ALLOWED_HOSTS = new Set([
  'my.hongik.ac.kr',
  'ap.hongik.ac.kr',
  'at.hongik.ac.kr',
  'www.hongik.ac.kr',
  'apps.hongik.ac.kr',
  '203.249.67.222',
  '203.249.65.81',
  '223.194.83.66'
]);

const HOP_BY_HOP_HEADERS = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade'
]);

const BLOCKED_RESPONSE_HEADERS = new Set([
  'content-length',
  'content-security-policy',
  'cross-origin-embedder-policy',
  'cross-origin-opener-policy',
  'cross-origin-resource-policy',
  'set-cookie',
  'strict-transport-security',
  'x-content-type-options',
  'x-frame-options'
]);

const TARGET_SET_COOKIES_HEADER = 'X-Target-Set-Cookies';
const TARGET_LOCATION_HEADER = 'X-Target-Location';
const TARGET_COOKIE_REQUEST_HEADER = 'x-target-cookie';
const TARGET_ORIGIN_REQUEST_HEADER = 'x-target-origin';
const TARGET_REFERER_REQUEST_HEADER = 'x-target-referer';
const TARGET_FOLLOW_REDIRECTS_REQUEST_HEADER = 'x-target-follow-redirects';
const SUPPORTED_CONTENT_ENCODINGS = ['br', 'gzip'];

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

module.exports = async function handler(req, res) {
  const startedAt = Date.now();
  try {
    if (req.method === 'OPTIONS') {
      res.statusCode = 204;
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
      res.setHeader(
        'Access-Control-Allow-Headers',
        [
          'Content-Type',
          'Accept',
          'X-Target-Cookie',
          'X-Target-Origin',
          'X-Target-Referer',
          'X-Target-Follow-Redirects'
        ].join(',')
      );
      res.setHeader(
        'Access-Control-Expose-Headers',
        [TARGET_SET_COOKIES_HEADER, TARGET_LOCATION_HEADER].join(',')
      );
      res.end();
      return;
    }

    const targetUrl = readTargetUrl(req);
    if (!targetUrl) {
      console.warn('[proxy] missing target url', req.method, req.url);
      res.statusCode = 400;
      res.end('Missing url query parameter.');
      return;
    }

    if (!ALLOWED_HOSTS.has(targetUrl.hostname)) {
      console.warn('[proxy] blocked target', req.method, safeUrl(targetUrl));
      res.statusCode = 403;
      res.end('Proxy target is not allowed.');
      return;
    }

    const body = await readRequestBody(req);
    console.info(
      '[proxy] ->',
      req.method,
      safeUrl(targetUrl),
      `body=${body.length}B`,
      `cookie=${req.headers['x-target-cookie'] ? 'yes' : 'no'}`
    );
    const upstream = await requestUpstream(
      targetUrl,
      req,
      body,
      0,
      startedAt + PROXY_REQUEST_BUDGET_SECONDS * SECOND_MS
    );
    console.info(
      '[proxy] <-',
      upstream.statusCode || 502,
      req.method,
      safeUrl(targetUrl),
      `${upstream.body.length}B`,
      `${Date.now() - startedAt}ms`
    );

    res.statusCode = upstream.statusCode || 502;
    const shouldFollow = shouldFollowRedirects(req.headers);
    for (const [name, value] of Object.entries(upstream.headers)) {
      const lowerName = name.toLowerCase();
      if (!shouldForwardResponseHeader(lowerName, shouldFollow)) {
        continue;
      }
      if (value !== undefined) {
        res.setHeader(name, value);
      }
    }
    if (upstream.targetSetCookies.length > 0) {
      res.setHeader(
        TARGET_SET_COOKIES_HEADER,
        encodeTargetSetCookies(upstream.targetSetCookies)
      );
    }
    if (!shouldFollow && upstream.headers.location) {
      res.setHeader(
        TARGET_LOCATION_HEADER,
        firstHeaderValue(upstream.headers.location)
      );
    }
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader(
      'Access-Control-Expose-Headers',
      [TARGET_SET_COOKIES_HEADER, TARGET_LOCATION_HEADER].join(',')
    );
    res.end(upstream.body);
  } catch (error) {
    console.error('[proxy] !!', error);
    res.statusCode = 502;
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.end(JSON.stringify({ error: error.message || 'Proxy request failed.' }));
  }
};

function safeUrl(url) {
  const safe = new URL(url.toString());
  for (const key of [...safe.searchParams.keys()]) {
    const lowerKey = key.toLowerCase();
    if (
      lowerKey.includes('pass') ||
      lowerKey.includes('pwd') ||
      lowerKey.includes('token') ||
      lowerKey.includes('key')
    ) {
      safe.searchParams.set(key, '***');
    }
  }
  return safe.toString();
}

function readTargetUrl(req) {
  const host = req.headers.host || 'localhost';
  const requestUrl = new URL(req.url, `http://${host}`);
  const rawTargetUrl = requestUrl.searchParams.get('url');
  if (!rawTargetUrl) {
    return null;
  }
  return new URL(rawTargetUrl);
}

function readRequestBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function requestUpstream(
  targetUrl,
  req,
  body,
  redirectCount = 0,
  deadlineMs = Date.now() + PROXY_REQUEST_BUDGET_SECONDS * SECOND_MS,
  targetSetCookies = []
) {
  const maxAttempts =
    redirectCount === 0 && isRetryableMethod(req.method)
      ? MAX_SAFE_METHOD_ATTEMPTS
      : 1;
  let lastError;

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

      upstream.targetSetCookies = targetSetCookies;
      return upstream;
    } catch (error) {
      lastError = error;
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

  throw lastError || new Error(`Upstream request failed: ${safeUrl(targetUrl)}`);
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
  const timeoutMs = requestTimeoutMs(deadlineMs);

  const upstream = await new Promise((resolve, reject) => {
    const upstreamReq = client.request(
      targetUrl,
      {
        method: req.method,
        headers,
        agent
      },
      (upstreamRes) => {
        const chunks = [];
        upstreamRes.on('data', (chunk) => chunks.push(chunk));
        upstreamRes.on('end', () => {
          resolve({
            statusCode: upstreamRes.statusCode,
            headers: upstreamRes.headers,
            body: Buffer.concat(chunks)
          });
        });
      }
    );

    upstreamReq.on('error', reject);
    upstreamReq.setTimeout(timeoutMs, () => {
      const error = new Error(`Upstream timeout: ${safeUrl(targetUrl)}`);
      error.code = 'ETIMEDOUT';
      upstreamReq.destroy(error);
    });
    if (body.length > 0) {
      upstreamReq.write(body);
    }
    upstreamReq.end();
  });
  collectTargetSetCookies(targetSetCookies, targetUrl, upstream.headers['set-cookie']);

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
      headers: {
        ...req.headers,
        cookie: mergeCookies(req.headers.cookie, upstream.headers['set-cookie']),
        'x-target-cookie': mergeCookies(
          req.headers['x-target-cookie'],
          upstream.headers['set-cookie']
        )
      }
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

function mergeCookies(existingCookieHeader, setCookieHeader) {
  const cookies = new Map();
  for (const part of String(existingCookieHeader || '').split(';')) {
    const trimmed = part.trim();
    if (!trimmed || !trimmed.includes('=')) {
      continue;
    }
    const [name, ...valueParts] = trimmed.split('=');
    cookies.set(name, valueParts.join('='));
  }

  const setCookies = Array.isArray(setCookieHeader)
    ? setCookieHeader
    : setCookieHeader
      ? [setCookieHeader]
      : [];
  for (const setCookie of setCookies) {
    const firstPart = String(setCookie).split(';')[0];
    if (!firstPart.includes('=')) {
      continue;
    }
    const [name, ...valueParts] = firstPart.split('=');
    cookies.set(name.trim(), valueParts.join('='));
  }

  return [...cookies.entries()]
    .map(([name, value]) => `${name}=${value}`)
    .join('; ');
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

function encodeTargetSetCookies(targetSetCookies) {
  return Buffer.from(JSON.stringify(targetSetCookies), 'utf8').toString('base64url');
}

function shouldFollowRedirects(requestHeaders) {
  return (
    String(requestHeaders[TARGET_FOLLOW_REDIRECTS_REQUEST_HEADER] || 'true')
      .trim()
      .toLowerCase() !== 'false'
  );
}

function firstHeaderValue(value) {
  return Array.isArray(value) ? value[0] : String(value);
}

function shouldForwardResponseHeader(headerName, shouldFollowRedirects) {
  return !(
    HOP_BY_HOP_HEADERS.has(headerName) ||
    BLOCKED_RESPONSE_HEADERS.has(headerName) ||
    (headerName === 'location' && !shouldFollowRedirects)
  );
}

function negotiatedAcceptEncoding(value) {
  if (!value) {
    return 'identity';
  }

  const qualityByEncoding = new Map();
  let wildcardQuality;
  for (const item of firstHeaderValue(value).split(',')) {
    const [rawEncoding, ...rawParameters] = item.trim().split(';');
    const encoding = rawEncoding.trim().toLowerCase();
    if (!encoding) {
      continue;
    }

    let quality = 1;
    for (const rawParameter of rawParameters) {
      const [name, rawValue] = rawParameter.trim().split('=');
      if (name?.toLowerCase() !== 'q') {
        continue;
      }
      const parsedQuality = Number(rawValue);
      quality = Number.isFinite(parsedQuality)
        ? Math.max(0, Math.min(1, parsedQuality))
        : 0;
    }

    if (encoding === '*') {
      wildcardQuality = quality;
    } else {
      qualityByEncoding.set(encoding, quality);
    }
  }

  const accepted = SUPPORTED_CONTENT_ENCODINGS
    .map((encoding) => ({
      encoding,
      quality: qualityByEncoding.get(encoding) ?? wildcardQuality ?? 0
    }))
    .filter(({ quality }) => quality > 0)
    .sort((left, right) => right.quality - left.quality);

  if (accepted.length === 0) {
    return 'identity';
  }
  return accepted
    .map(({ encoding, quality }) =>
      quality === 1 ? encoding : `${encoding};q=${quality}`
    )
    .join(', ');
}

function buildUpstreamHeaders(requestHeaders, targetUrl) {
  const headers = {};
  for (const [name, value] of Object.entries(requestHeaders)) {
    const lowerName = name.toLowerCase();
    if (
      HOP_BY_HOP_HEADERS.has(lowerName) ||
      lowerName === 'host' ||
      lowerName === 'accept-encoding' ||
      lowerName === 'content-length' ||
      lowerName === 'origin' ||
      lowerName === 'referer' ||
      lowerName.startsWith('x-target-') ||
      lowerName.startsWith('sec-')
    ) {
      continue;
    }
    headers[name] = value;
  }

  headers.host = targetUrl.host;
  headers['accept-encoding'] = negotiatedAcceptEncoding(
    requestHeaders['accept-encoding']
  );
  if (requestHeaders[TARGET_COOKIE_REQUEST_HEADER]) {
    headers.cookie = requestHeaders[TARGET_COOKIE_REQUEST_HEADER];
  }
  const targetOrigin = validatedTargetHeader(
    requestHeaders[TARGET_ORIGIN_REQUEST_HEADER],
    'origin'
  );
  if (targetOrigin) {
    headers.origin = targetOrigin;
  }
  const targetReferer = validatedTargetHeader(
    requestHeaders[TARGET_REFERER_REQUEST_HEADER],
    'referer'
  );
  if (targetReferer) {
    headers.referer = targetReferer;
  }
  headers['user-agent'] =
    requestHeaders['user-agent'] ||
    'Mozilla/5.0 AppleWebKit/537.36 HongikInganPWA';

  return headers;
}

function validatedTargetHeader(value, headerName) {
  if (!value) {
    return null;
  }
  const rawValue = firstHeaderValue(value);
  let url;
  try {
    url = new URL(rawValue);
  } catch {
    throw new Error(`Invalid target ${headerName} header.`);
  }
  if (url.protocol !== 'https:' || !ALLOWED_HOSTS.has(url.hostname)) {
    throw new Error(`Target ${headerName} is not allowed.`);
  }
  return headerName === 'origin' ? url.origin : url.toString();
}

module.exports._test = {
  buildUpstreamHeaders,
  collectTargetSetCookies,
  encodeTargetSetCookies,
  negotiatedAcceptEncoding,
  shouldForwardResponseHeader,
  shouldFollowRedirects,
  validatedTargetHeader
};
