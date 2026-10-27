const { campusDay, validDate } = require('./meal_vote_identity');
const { readVoteAccount } = require('./meal_vote_auth');
const { fetchLunchPoll } = require('./meal_choice_feed');

function send(res, status, data, cache = 'no-store') {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', cache === 'no-store' ? 'private, no-store' : 'public, max-age=0, must-revalidate');
  res.setHeader('Vercel-CDN-Cache-Control', cache);
  res.end(JSON.stringify(data));
}

async function readBody(req) {
  if (!String(req.headers['content-type'] || '').startsWith('application/json')) throw new Error('INVALID_BODY');
  let body = req.body;
  if (body === undefined) {
    body = '';
    for await (const chunk of req) {
      body += chunk;
      if (Buffer.byteLength(body) > 2048) throw new Error('INVALID_BODY');
    }
  }
  if (Buffer.byteLength(typeof body === 'string' ? body : JSON.stringify(body)) > 2048) throw new Error('INVALID_BODY');
  return typeof body === 'string' ? JSON.parse(body) : body;
}

function createHandler({ repository, fetchPoll = fetchLunchPoll, clock = () => new Date(), env = process.env } = {}) {
  return async function handle(req, res) {
    try {
      if (!['GET', 'PUT'].includes(req.method)) {
        res.setHeader('Allow', 'GET, PUT');
        return send(res, 405, { error: 'METHOD_NOT_ALLOWED' });
      }
      const url = new URL(req.url, 'https://localhost');
      const writing = req.method === 'PUT';
      const personal = writing || url.searchParams.get('mine') === '1';
      const body = writing ? await readBody(req) : null;
      const date = writing ? body?.date : url.searchParams.get('date');
      if (!validDate(date, clock())) return send(res, 400, { error: 'INVALID_DATE' });
      const account = personal ? readVoteAccount(req) : null;
      if (writing) {
        if (date !== campusDay(clock())) return send(res, 409, { error: 'VOTING_CLOSED' });
        if (!/^[a-f0-9]{64}$/.test(body?.id || '') || ![null, 'A', 'B'].includes(body?.choice)) {
          return send(res, 400, { error: 'INVALID_VOTE' });
        }
      }
      const repo = repository || require('./meal_choice_repository').createRepository(env);
      if (!personal || writing) {
        const synced = await repo.lastSync(date);
        const age = synced ? clock() - new Date(synced) : Infinity;
        const final = date < campusDay(clock()) && synced && campusDay(new Date(synced)) > date;
        if (!final && !(age >= 0 && age < 300000)) {
          await repo.sync(date, await fetchPoll(date));
          await repo.purge();
        }
      }
      const poll = await repo.poll(date);
      if (writing) {
        if (poll?.id !== body.id) return send(res, 409, { error: 'MENU_UNAVAILABLE' });
        return send(res, 200, await repo.vote(poll.id, account, body.choice));
      }
      if (personal) return send(res, 200, { id: poll?.id || null, choice: poll ? await repo.choice(poll.id, account) : null });
      return send(res, 200, { date, poll }, `public, s-maxage=${date < campusDay(clock()) ? 3600 : 30}, stale-while-revalidate=30`);
    } catch (error) {
      const message = error?.message || '';
      if (message === 'AUTHENTICATION_REQUIRED') return send(res, 401, { error: message });
      if (error instanceof SyntaxError || message === 'INVALID_BODY') return send(res, 400, { error: 'INVALID_BODY' });
      for (const code of ['VOTING_CLOSED', 'MENU_UNAVAILABLE']) {
        if (message.includes(code)) return send(res, 409, { error: code });
      }
      return send(res, 503, { error: 'VOTING_UNAVAILABLE' });
    }
  };
}
module.exports = { createHandler };
