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
  'content-encoding',
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

const UPSTREAM_TIMEOUT_MS = 8500;

module.exports = async function handler(req, res) {
  const startedAt = Date.now();
  try {
    if (req.method === 'OPTIONS') {
      res.statusCode = 204;
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
      res.setHeader(
        'Access-Control-Allow-Headers',
        'Content-Type,Accept,X-Target-Cookie'
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
    const upstream = await requestUpstream(targetUrl, req, body);
    console.info(
      '[proxy] <-',
      upstream.statusCode || 502,
      req.method,
      safeUrl(targetUrl),
      `${upstream.body.length}B`,
      `${Date.now() - startedAt}ms`
    );

    res.statusCode = upstream.statusCode || 502;
    for (const [name, value] of Object.entries(upstream.headers)) {
      const lowerName = name.toLowerCase();
      if (
        HOP_BY_HOP_HEADERS.has(lowerName) ||
        BLOCKED_RESPONSE_HEADERS.has(lowerName)
      ) {
        continue;
      }
      if (value !== undefined) {
        res.setHeader(name, value);
      }
    }
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Access-Control-Allow-Origin', '*');
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

async function requestUpstream(targetUrl, req, body, redirectCount = 0) {
  const client = targetUrl.protocol === 'http:' ? http : https;
  const headers = buildUpstreamHeaders(req.headers, targetUrl);

  const upstream = await new Promise((resolve, reject) => {
    const upstreamReq = client.request(
      targetUrl,
      {
        method: req.method,
        headers
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
    upstreamReq.setTimeout(UPSTREAM_TIMEOUT_MS, () => {
      upstreamReq.destroy(new Error(`Upstream timeout: ${safeUrl(targetUrl)}`));
    });
    if (body.length > 0) {
      upstreamReq.write(body);
    }
    upstreamReq.end();
  });

  const location = upstream.headers.location;
  if (isRedirect(upstream.statusCode) && location && redirectCount < 5) {
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
    return requestUpstream(redirectUrl, nextReq, nextBody, redirectCount + 1);
  }

  return upstream;
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
      lowerName.startsWith('sec-')
    ) {
      continue;
    }
    headers[name] = value;
  }

  headers.host = targetUrl.host;
  headers['accept-encoding'] = 'identity';
  if (requestHeaders['x-target-cookie']) {
    headers.cookie = requestHeaders['x-target-cookie'];
  }
  headers['user-agent'] =
    requestHeaders['user-agent'] ||
    'Mozilla/5.0 AppleWebKit/537.36 HongikInganPWA';

  return headers;
}
