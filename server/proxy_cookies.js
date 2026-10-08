// Per-request cookie jar; never shared between users or persisted on the server.
const AUTH_DOMAINS = new Set(['hongik.ac.kr', 'my.hongik.ac.kr', 'ap.hongik.ac.kr', 'at.hongik.ac.kr']);
const domainMatches = (host, domain) => host === domain || host.endsWith(`.${domain}`);
const pathMatches = (path, scope) => path === scope ||
  (path.startsWith(scope) && (scope.endsWith('/') || path[scope.length] === '/'));
const defaultPath = (url) => url.pathname.slice(0, url.pathname.lastIndexOf('/')) || '/';

class ProxyCookieJar {
  constructor(url, headers) {
    this.cookies = [];
    const encoded = headers['x-target-cookie-store'];
    if (encoded !== undefined) {
      if (typeof encoded !== 'string' || encoded.length > 65536) throw new Error('Invalid cookie store.');
      const records = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
      if (!Array.isArray(records) || records.length > 200) throw new Error('Invalid cookie store.');
      for (const record of records) {
        if (!record || !AUTH_DOMAINS.has(record.domain) || typeof record.hostOnly !== 'boolean' ||
            typeof record.secure !== 'boolean' || typeof record.path !== 'string' || !record.path.startsWith('/') ||
            (record.expiresAt != null && !Number.isFinite(record.expiresAt))) throw new Error('Invalid cookie scope.');
        this.save(record);
      }
    } else {
      // Old clients only provide the initial target's Cookie header. Its scope
      // cannot be inferred; keep it on that host rather than leaking to another.
      for (const part of String(headers['x-target-cookie'] || '').split(';')) {
        const index = part.indexOf('=');
        if (index < 1) continue;
        this.save({ name: part.slice(0, index).trim(), value: part.slice(index + 1).trim(),
          domain: url.hostname, hostOnly: true, path: '/', secure: url.protocol === 'https:', expiresAt: null });
      }
    }
  }

  save(cookie) {
    if (typeof cookie.name !== 'string' || !/^[!#$%&'*+.^_`|~0-9A-Za-z-]+$/.test(cookie.name) ||
        typeof cookie.value !== 'string' || /[\x00-\x20\x7f;,]/.test(cookie.value)) throw new Error('Invalid cookie.');
    this.cookies = this.cookies.filter((old) =>
      old.name !== cookie.name || old.domain !== cookie.domain || old.path !== cookie.path);
    if (cookie.value && (cookie.expiresAt == null || cookie.expiresAt > Date.now())) this.cookies.push(cookie);
  }

  capture(url, setCookies) {
    for (const raw of (Array.isArray(setCookies) ? setCookies : setCookies ? [setCookies] : [])) {
      const [pair, ...parts] = String(raw).split(';');
      const index = pair.indexOf('=');
      if (index < 1) continue;
      const attributes = new Map(parts.map((part) => {
        const split = part.indexOf('=');
        return split < 0 ? [part.trim().toLowerCase(), ''] :
          [part.slice(0, split).trim().toLowerCase(), part.slice(split + 1).trim()];
      }));
      const rawDomain = attributes.get('domain');
      const hostOnly = !rawDomain;
      const domain = hostOnly ? url.hostname : rawDomain.toLowerCase().replace(/^\./, '');
      if (!AUTH_DOMAINS.has(domain) || !domainMatches(url.hostname, domain)) continue;
      const rawPath = attributes.get('path');
      const path = rawPath?.startsWith('/') ? rawPath : defaultPath(url);
      const maxAge = attributes.get('max-age');
      const expiry = Date.parse(attributes.get('expires'));
      const expiresAt = maxAge !== undefined && /^-?\d+$/.test(maxAge)
        ? Date.now() + Number(maxAge) * 1000 : Number.isFinite(expiry) ? expiry : null;
      try {
        this.save({ name: pair.slice(0, index).trim(), value: pair.slice(index + 1).trim(),
          domain, hostOnly, path, secure: attributes.has('secure'), expiresAt });
      } catch {
        // Ignore malformed upstream cookies like a browser cookie jar.
      }
    }
  }

  headerFor(url) {
    return this.cookies.filter((cookie) =>
      (cookie.expiresAt == null || cookie.expiresAt > Date.now()) &&
      (cookie.hostOnly ? cookie.domain === url.hostname : domainMatches(url.hostname, cookie.domain)) &&
      pathMatches(url.pathname || '/', cookie.path) && (!cookie.secure || url.protocol === 'https:'))
      .sort((a, b) => b.path.length - a.path.length)
      .map((cookie) => `${cookie.name}=${cookie.value}`).join('; ');
  }
}

module.exports = { ProxyCookieJar };
