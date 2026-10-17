const { timingSafeEqual } = require('node:crypto');
const { campusDay, validDate } = require('./meal_vote_identity');
const { fetchStudentLunch } = require('./meal_vote_feed');
const { verifyVoteAccount } = require('./meal_vote_auth');

function send(res, status, data, cache) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', cache ? 'public, max-age=0, must-revalidate' : 'private, no-store');
  res.setHeader('Vercel-CDN-Cache-Control', cache || 'no-store');
  res.end(JSON.stringify(data));
}

async function readBody(req) {
  if (!String(req.headers['content-type'] || '').startsWith('application/json')) throw new Error('INVALID_BODY');
  if (req.body !== undefined) {
    if (Buffer.byteLength(typeof req.body === 'string' ? req.body : JSON.stringify(req.body)) > 2048) throw new Error('INVALID_BODY');
    return typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  }
  let body = '';
  for await (const chunk of req) {
    body += chunk;
    if (Buffer.byteLength(body) > 2048) throw new Error('INVALID_BODY');
  }
  return JSON.parse(body);
}

function secureEquals(actual, expected) {
  if (!actual || !expected) return false;
  const a = Buffer.from(actual), b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

function createHandler({ repository, fetchMenus = fetchStudentLunch, verifyAccount = verifyVoteAccount, clock = () => new Date(), env = process.env } = {}) {
  const getRepository = () => repository || require('./meal_vote_repository').createRepository(env);
  async function sync(repo, date) {
    const lastSync = await repo.lastSync(date);
    const now = clock();
    const age = lastSync ? now - new Date(lastSync) : Infinity;
    const closedAndFinal = date < campusDay(now) && lastSync && campusDay(new Date(lastSync)) > date;
    if (closedAndFinal || (age >= 0 && age < 300000)) return;
    const meals = await fetchMenus(date);
    await repo.sync(date, meals);
    await repo.purge();
  }
  return async function handle(kind, req, res) {
    try {
      if (kind === 'vote-cleanup') {
        if (req.method !== 'GET') return send(res, 405, { error: 'METHOD_NOT_ALLOWED' });
        if (!secureEquals(req.headers.authorization, env.CRON_SECRET ? `Bearer ${env.CRON_SECRET}` : null)) {
          return send(res, 401, { error: 'UNAUTHORIZED' });
        }
        await getRepository().purge();
        return send(res, 200, { ok: true });
      }
      if (req.method !== (kind === 'vote' ? 'PUT' : 'GET')) {
        res.setHeader('Allow', kind === 'vote' ? 'PUT' : 'GET');
        return send(res, 405, { error: 'METHOD_NOT_ALLOWED' });
      }
      const url = new URL(req.url, 'https://localhost');
      const body = kind === 'vote' ? await readBody(req) : null;
      const date = body?.date ?? url.searchParams.get('date');
      if (!validDate(date, clock())) return send(res, 400, { error: 'INVALID_DATE' });
      const account = kind === 'vote' || kind === 'my-votes' ? await verifyAccount(req) : null;
      if (kind === 'vote') {
        if (date !== campusDay(clock())) return send(res, 409, { error: 'VOTING_CLOSED' });
        if (!body || !/^[a-f0-9]{64}$/.test(body.id || '') || ![-1, 0, 1].includes(body.choice)) {
          return send(res, 400, { error: 'INVALID_VOTE' });
        }
      }
      const repo = getRepository();
      if (kind === 'meals' || kind === 'vote-totals' || kind === 'vote') await sync(repo, date);
      const meals = await repo.meals(date);
      if (kind === 'vote') {
        if (!meals.some((meal) => meal.id === body.id)) return send(res, 409, { error: 'MENU_UNAVAILABLE' });
        return send(res, 200, await repo.vote(body.id, account, body.choice));
      }
      if (kind === 'my-votes') return send(res, 200, { votes: await repo.choices(meals, account) });
      const closed = date < campusDay(clock());
      const ttl = closed ? 3600 : kind === 'meals' ? 300 : 30;
      const output = meals.map(({ id, items, likes, dislikes, version }) => kind === 'meals'
        ? { id, items } : { id, likes, dislikes, version });
      return send(res, 200, { date, meals: output },
        `public, s-maxage=${ttl}, stale-while-revalidate=${kind === 'meals' ? 0 : 30}`);
    } catch (error) {
      const message = error?.message || '';
      if (['AUTHENTICATION_REQUIRED', 'ACCOUNT_MISMATCH'].includes(message)) {
        return send(res, 401, { error: message });
      }
      if (error instanceof SyntaxError || message === 'INVALID_BODY') return send(res, 400, { error: 'INVALID_BODY' });
      if (message.includes('VOTING_CLOSED')) return send(res, 409, { error: 'VOTING_CLOSED' });
      if (message.includes('MENU_UNAVAILABLE')) return send(res, 409, { error: 'MENU_UNAVAILABLE' });
      // Never log raw requests, tokens, database URLs, or database error details.
      return send(res, 503, { error: 'VOTING_UNAVAILABLE' });
    }
  };
}

module.exports = { createHandler };
