const { TextDecoder } = require('util');
const { createProxyUpstream, SECOND_MS, PROXY_REQUEST_BUDGET_SECONDS } = require('../server/proxy_upstream');

const {
  PublicResponseCache,
  classifyPublicCachePolicy,
  isSeatTarget,
  isCacheablePublicResponse,
  publicCacheKey,
  shouldBypassPublicCache
} = require('../server/proxy_cache');

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
  'age',
  'cache-control',
  'cdn-cache-control',
  'content-length',
  'content-security-policy',
  'cross-origin-embedder-policy',
  'cross-origin-opener-policy',
  'cross-origin-resource-policy',
  'expires',
  'pragma',
  'set-cookie',
  'strict-transport-security',
  'vercel-cdn-cache-control',
  'x-content-type-options',
  'x-frame-options'
]);

const TARGET_SET_COOKIES_HEADER = 'X-Target-Set-Cookies';
const TARGET_LOCATION_HEADER = 'X-Target-Location';
const TARGET_ORIGIN_REQUEST_HEADER = 'x-target-origin';
const TARGET_REFERER_REQUEST_HEADER = 'x-target-referer';
const TARGET_FOLLOW_REDIRECTS_REQUEST_HEADER = 'x-target-follow-redirects';
const SUPPORTED_CONTENT_ENCODINGS = ['br', 'gzip'];
const PROXY_CACHE_STATUS_HEADER = 'X-Proxy-Cache';
const PROXY_FETCHED_AT_HEADER = 'X-Proxy-Fetched-At';
const PROXY_RESOURCE_HEADER = 'X-Proxy-Resource';
const PROXY_CACHE_DAY_HEADER = 'X-Proxy-Cache-Day';
const EXPOSED_RESPONSE_HEADERS = [
  TARGET_SET_COOKIES_HEADER,
  TARGET_LOCATION_HEADER,
  PROXY_CACHE_STATUS_HEADER,
  PROXY_FETCHED_AT_HEADER,
  PROXY_RESOURCE_HEADER,
  PROXY_CACHE_DAY_HEADER,
  'Retry-After'
];

const { requestUpstream, shouldRetry, isRetryableError, collectTargetSetCookies } = createProxyUpstream({
  allowedHosts: ALLOWED_HOSTS,
  buildUpstreamHeaders,
  safeUrl,
  shouldFollowRedirects
});

const publicResponseCache = new PublicResponseCache();
const publicRequestsInFlight = new Map();

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
          'Cache-Control',
          'Pragma',
          'X-Target-Cookie',
          'X-Target-Origin',
          'X-Target-Referer',
          'X-Target-Follow-Redirects',
          'X-Target-Cookie-Store',
          'X-Target-Retry'
        ].join(',')
      );
      res.setHeader(
        'Access-Control-Expose-Headers',
        EXPOSED_RESPONSE_HEADERS.join(',')
      );
      res.end();
      return;
    }

    const proxyRequestUrl = readProxyRequestUrl(req);
    const targetUrl = readTargetUrl(proxyRequestUrl);
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

    const publicCachePolicy = classifyPublicCachePolicy(
      req,
      targetUrl,
      proxyRequestUrl
    );
    const body = await readRequestBody(req);
    console.info(
      '[proxy] ->',
      req.method,
      safeUrl(targetUrl),
      `body=${body.length}B`,
      `cookieMetadata=${req.headers['x-target-cookie-store'] !== undefined || req.headers['x-target-cookie'] ? 'yes' : 'no'}`
    );
    const acceptEncoding = upstreamAcceptEncoding(req.headers, targetUrl);
    const cacheKey = publicCachePolicy
      ? publicCacheKey(publicCachePolicy, targetUrl, req.headers, acceptEncoding)
      : null;
    const bypassPublicCache = publicCachePolicy !== null &&
      shouldBypassPublicCache(req.headers);
    let cacheStatus = publicCachePolicy ? 'MISS' : 'BYPASS';
    let upstream = cacheKey && !bypassPublicCache
      ? publicResponseCache.get(cacheKey)
      : null;

    if (upstream) {
      cacheStatus = 'MEMORY_HIT';
    } else {
      cacheStatus = bypassPublicCache ? 'REVALIDATED' : cacheStatus;
      const requestOperation = () => requestUpstream(
        targetUrl,
        req,
        body,
        0,
        startedAt + PROXY_REQUEST_BUDGET_SECONDS * SECOND_MS
      );
      try {
        if (cacheKey) {
          const sharedResult = await sharePublicRequest(cacheKey, requestOperation);
          upstream = sharedResult.upstream;
          if (sharedResult.shared) {
            cacheStatus = 'COALESCED';
          }
        } else {
          upstream = await requestOperation();
        }
      } catch (error) {
        const fallback = publicCachePolicy?.type === 'menu' &&
          (isRetryableError(error) ||
            ['ENOTFOUND', 'ENETUNREACH', 'EHOSTUNREACH'].includes(error.code)) &&
          publicResponseCache.get(cacheKey);
        if (!fallback) throw error;
        upstream = fallback;
        cacheStatus = 'FALLBACK';
      }
      if (publicCachePolicy?.type === 'menu' && upstream.statusCode >= 500) {
        const fallback = publicResponseCache.get(cacheKey);
        if (fallback) {
          upstream = fallback;
          cacheStatus = 'FALLBACK';
        }
      }
      if (isSeatTarget(targetUrl)) {
        upstream = normalizeSeatResponse(upstream);
      }
      upstream.fetchedAt ||= new Date().toISOString();
      if (cacheKey && cacheStatus !== 'FALLBACK' &&
          isCacheablePublicResponse(publicCachePolicy, upstream)) {
        const nowMs = Date.now();
        publicResponseCache.set(
          cacheKey,
          upstream,
          publicCachePolicy.expiresAtMs == null
            ? publicCachePolicy.memoryTtlMs
            : Math.max(0, publicCachePolicy.expiresAtMs - nowMs),
          nowMs
        );
      }
    }
    console.info(
      '[proxy] <-',
      upstream.statusCode || 502,
      req.method,
      safeUrl(targetUrl),
      `${upstream.body.length}B`,
      `cache=${cacheStatus}`,
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
    applyProxyCacheHeaders(
      res,
      publicCachePolicy,
      upstream,
      cacheStatus
    );
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader(
      'Access-Control-Expose-Headers',
      EXPOSED_RESPONSE_HEADERS.join(',')
    );
    res.end(upstream.body);
  } catch (error) {
    console.error('[proxy] !!', error);
    res.statusCode = 502;
    res.setHeader('Cache-Control', 'no-store');
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

function readProxyRequestUrl(req) {
  const host = req.headers.host || 'localhost';
  return new URL(req.url, `http://${host}`);
}

function readTargetUrl(requestUrl) {
  const rawTargetUrl = requestUrl.searchParams.get('url');
  if (!rawTargetUrl) {
    return null;
  }
  return new URL(rawTargetUrl);
}

async function sharePublicRequest(cacheKey, requestOperation) {
  const existing = publicRequestsInFlight.get(cacheKey);
  if (existing) {
    return { upstream: await existing, shared: true };
  }

  const operation = requestOperation().finally(() => {
    if (publicRequestsInFlight.get(cacheKey) === operation) {
      publicRequestsInFlight.delete(cacheKey);
    }
  });
  publicRequestsInFlight.set(cacheKey, operation);
  return { upstream: await operation, shared: false };
}

function applyProxyCacheHeaders(res, policy, upstream, cacheStatus) {
  res.setHeader(PROXY_CACHE_STATUS_HEADER, cacheStatus);
  if (!isCacheablePublicResponse(policy, upstream)) {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vercel-CDN-Cache-Control', 'no-store');
    return;
  }

  res.setHeader('Cache-Control', cacheStatus === 'FALLBACK' ? 'no-store' : policy.cacheControl);
  const cdnCacheControl = policy.type === 'menu' &&
      policy.vercelCacheControl !== 'no-store'
    ? `public, max-age=${Math.max(0, Math.floor((policy.expiresAtMs - Date.now()) / 1000))}`
    : policy.vercelCacheControl;
  res.setHeader('Vercel-CDN-Cache-Control', cacheStatus === 'FALLBACK' ? 'no-store' : cdnCacheControl);
  res.setHeader(PROXY_RESOURCE_HEADER, policy.type);
  res.setHeader(PROXY_FETCHED_AT_HEADER, upstream.fetchedAt);
  if (policy.cacheDay) {
    res.setHeader(PROXY_CACHE_DAY_HEADER, policy.cacheDay);
  }
  const varyWithAccept = mergeVaryHeader(res.getHeader('Vary'), 'Accept');
  res.setHeader('Vary', mergeVaryHeader(varyWithAccept, 'Accept-Encoding'));
}

function mergeVaryHeader(existingValue, value) {
  const values = String(existingValue || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  if (!values.some((item) => item.toLowerCase() === value.toLowerCase())) {
    values.push(value);
  }
  return values.join(', ');
}

function readRequestBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
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

function upstreamAcceptEncoding(requestHeaders, targetUrl) {
  return isSeatTarget(targetUrl)
    ? 'identity'
    : negotiatedAcceptEncoding(requestHeaders['accept-encoding']);
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
      lowerName === 'cookie' ||
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
  headers['accept-encoding'] = upstreamAcceptEncoding(requestHeaders, targetUrl);
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

function normalizeSeatResponse(upstream) {
  if (
    upstream.statusCode !== 200 ||
    !Buffer.isBuffer(upstream.body) ||
    upstream.body.length === 0
  ) {
    return upstream;
  }

  const decoded = new TextDecoder('euc-kr').decode(upstream.body);
  const headers = { ...upstream.headers };
  delete headers['content-encoding'];
  delete headers['content-length'];
  headers['content-type'] = 'text/html; charset=utf-8';

  return {
    ...upstream,
    headers,
    body: Buffer.from(decoded, 'utf8')
  };
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
  requestUpstream,
  shouldRetry,
  applyProxyCacheHeaders,
  buildUpstreamHeaders,
  collectTargetSetCookies,
  encodeTargetSetCookies,
  mergeVaryHeader,
  negotiatedAcceptEncoding,
  normalizeSeatResponse,
  shouldForwardResponseHeader,
  shouldFollowRedirects,
  validatedTargetHeader
};
