const { load } = require('cheerio');

function normalizeStudentId(value) {
  const id = typeof value === 'string' ? value.trim().toUpperCase() : '';
  if (!/^[A-Z0-9]{6,12}$/.test(id) || !/[0-9]/.test(id)) throw new Error('AUTHENTICATION_REQUIRED');
  return id;
}

function studentIdFromPage(body) {
  const $ = load(body);
  for (const script of $('script').toArray()) {
    const immediate = $(script).text().replace(/^(?:\s+|\/\/[^\r\n]*(?:\r?\n|$)|\/\*[\s\S]*?\*\/)*/, '');
    if (/^(?:window\s*\.\s*)?alert\s*\(\s*["'][^"']*장시간 사용이 없어 로그아웃/.test(immediate) ||
        /^document\s*\.\s*location\s*\.\s*replace\s*\(\s*["']https?:\/\/(?:ap\.hongik\.ac\.kr\/site\/login\/logout\.php|(?:www\.)?hongik\.ac\.kr\/?)["']\s*\)/i.test(immediate)) {
      throw new Error('AUTHENTICATION_REQUIRED');
    }
  }
  $('script, style').remove();
  const text = $.root().text();
  if (/통합\s*로그인|장시간 사용이 없어 로그아웃/.test(text) ||
      $('input[name="PASSWD"]').length ||
      $('input[name="USER_ID"]').toArray().some((input) => $(input).attr('type')?.toLowerCase() !== 'hidden')) {
    throw new Error('AUTHENTICATION_REQUIRED');
  }
  if (/시스템 연동/.test(text) && /오류/.test(text)) throw new Error('IDENTITY_UNAVAILABLE');
  const candidates = [];
  // Accept explicit server-rendered identity fields, never arbitrary text IDs,
  // query parameters, script variables, or a student ID supplied by the client.
  for (const input of $('input[type="hidden"]').toArray()) {
    if (/^(USER_ID|STUD_NO|STUDENT_ID|STUDENT_NO|HAKBUN)$/i.test($(input).attr('name') || '')) {
      candidates.push($(input).val());
    }
  }
  for (const cell of $('th, td, dt').toArray()) {
    if (/^학\s*번\s*[:：]?$/.test($(cell).text().trim())) {
      candidates.push($(cell).next('td, dd').text().trim());
    }
  }
  const ids = new Set(candidates.filter(Boolean).map(normalizeStudentId));
  if (ids.size !== 1) throw new Error('IDENTITY_UNAVAILABLE');
  return [...ids][0];
}

async function verifyVoteAccount(req, fetcher = fetch) {
  const session = req.headers['x-vote-session'];
  const expected = normalizeStudentId(req.headers['x-vote-account']);
  if (typeof session !== 'string' || !/^[A-Za-z0-9._-]{8,256}$/.test(session)) {
    throw new Error('AUTHENTICATION_REQUIRED');
  }
  // Only the attendance host receives its JSESSIONID. No redirects, URL input,
  // password forwarding, cookie persistence, or response-body logging.
  const response = await fetcher('https://at.hongik.ac.kr/index.jsp', {
    redirect: 'manual', signal: AbortSignal.timeout(5000),
    headers: { Cookie: `JSESSIONID=${session}`, Referer: 'https://at.hongik.ac.kr/login.jsp' }
  });
  if ([301, 302, 303, 307, 308, 401, 403].includes(response.status)) throw new Error('AUTHENTICATION_REQUIRED');
  if (!response.ok) throw new Error('IDENTITY_UNAVAILABLE');
  const charset = /charset=([^;\s]+)/i.exec(response.headers.get('content-type') || '')?.[1] || 'utf-8';
  const body = new TextDecoder(charset).decode(await response.arrayBuffer());
  const verified = studentIdFromPage(body);
  if (verified !== expected) throw new Error('ACCOUNT_MISMATCH');
  return verified;
}

module.exports = { normalizeStudentId, studentIdFromPage, verifyVoteAccount };
